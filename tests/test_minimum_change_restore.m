function report = test_minimum_change_restore()
% 用解析投影和历史三种优先级分支检验次级恢复，不以闭环排名作为正确性依据。
root=ca_setup(); stream=RandStream('mt19937ar','Seed',20261030);
projection_error=0;
for k=1:40
    M=randn(stream,3,6); held=0.02*randn(stream,6,1); candidate=0.02*randn(stream,6,1);
    expected=held+pinv(M)*(M*candidate-M*held);
    [u,info]=ca_restore_minimum_change(M,candidate,held,-ones(6,1),ones(6,1));
    projection_error=max(projection_error,norm(u-expected,Inf));
    assert(norm(u-expected,Inf)<1e-7 && info.exitflag>0,'无边界解析投影不一致。');
end
source=fullfile(root,'tests','fixtures','minimum_change_history.mat');
% 保留曾使内点法达到迭代上限的真实边界退化输入，作为求解可靠性回归。
fixture=load(fullfile(root,'tests','fixtures','minimum_change_degenerate.mat'));
[u,diagnosis]=ca_restore_minimum_change(fixture.matrix,fixture.candidate,fixture.held,fixture.lower,fixture.upper);
assert(diagnosis.exitflag>0 && norm(fixture.matrix*(u-fixture.candidate),Inf)<1e-7, ...
    '边界退化问题回归失败。');
near_path=fullfile(root,'tests','fixtures','minimum_change_near_boundary.mat');
if isfile(near_path)
    near=load(near_path);
    [u,diagnosis]=ca_restore_minimum_change(near.matrix,near.candidate,near.held,near.lower,near.upper);
    assert(diagnosis.exitflag>0 && norm(near.matrix*(u-near.candidate),Inf)<1e-7,'98%近边界恢复回归失败。');
end
d=load(source,'results'); r=d.results; log=r.logs.PCA_PREDICTIVE;
legacy=r.config; legacy.predictive_restore_mode="legacy_norm";
modern=legacy; modern.predictive_restore_mode="minimum_change";
indices=(1:numel(r.reference.time_s))';
effect_error=0; improved=0; modes=zeros(3,1);
for index=indices'
    timing=ca_pwm_timing(r.reference.time_s(index),legacy,log.allocation_held_command_rad(index,:)');
    vh=log.v_h(index,:)'; vc=log.v_c(index,:)'; delta=log.estimated_delta_rad(index,:)';
    [before,a]=ca_allocate("PCA_PREDICTIVE",vh,vc,delta,r.model,legacy,timing);
    [after,b]=ca_allocate("PCA_PREDICTIVE",vh,vc,delta,r.model,modern,timing);
    assert(a.mode==b.mode && isequaln(a.lambda,b.lambda) && isequaln(a.beta,b.beta), ...
        '次级恢复改变了原优先级分支或缩放系数。');
    error=norm(a.allocated_effect-b.allocated_effect,Inf); effect_error=max(effect_error,error);
    assert(error<1e-7 && b.restore_exitflag>0,'次级恢复没有保持原预测虚拟控制。');
    assert(norm(after-timing.held_command)^2<=norm(before-timing.held_command)^2+1e-7, ...
        '新恢复比原恢复的命令变化更大。');
    improved=improved+(norm(after-timing.held_command)<norm(before-timing.held_command)-1e-5);
    modes(b.mode+1)=modes(b.mode+1)+1;
end
assert(all(modes>0) && improved>0,'测试未覆盖三分支或没有覆盖实际改进。');
old=rmfield(ca_config(),'predictive_restore_mode'); old=ca_validate_config(old);
assert(old.predictive_restore_mode=="legacy_norm",'旧配置未保持历史行为。');
report=struct('analytic_projection_cases',40,'max_projection_error_rad',projection_error, ...
    'history_cases',numel(indices),'branch_counts',modes,'strictly_improved_cases',improved, ...
    'max_allocated_effect_error_rad_s2',effect_error);
folder=fullfile(root,'results','validation'); if ~isfolder(folder), mkdir(folder); end
save(fullfile(folder,'minimum_change_restore.mat'),'report'); disp(report);
end
