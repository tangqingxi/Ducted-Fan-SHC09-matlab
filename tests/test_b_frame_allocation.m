function report = test_b_frame_allocation()
root=ca_setup();
cfg=ca_validate_config(ca_config());
model=ca_model(cfg);
cfg_alloc=ca_allocator_config(cfg);
timing=ca_pwm_timing(0.001,cfg_alloc,model.trim_delta_rad);
methods=["WLS","DA_NS","PCA_STATIC","PCA_PREDICTIVE","DCA"];
vh=model.acceleration_matrix*model.trim_delta_rad+[0.02;-0.01;0.015]; vc=[0.005;0.003;-0.005];
results=struct(); max_residual=0;
for method=methods
    [command,info]=ca_allocate(method,vh,vc,model.trim_delta_rad,model,cfg_alloc,timing);
    assert(isequal(size(command),[6,1]) && all(isfinite(command)),'命令维度/有限性错误。');
    assert(all(command>=model.command_lower-1e-7 & command<=model.command_upper+1e-7),'命令越界。');
    effect=model.acceleration_matrix*command;
    effect_alloc=info.allocated_effect(:);
    if isfield(info,'native_predicted_delta') && all(isfinite(info.native_predicted_delta))
        effect_pred=model.acceleration_matrix*info.native_predicted_delta;
        assert(norm(effect_alloc-effect_pred,Inf)<1e-8,'分配的预测效果与 B_acc*预测舵角不一致。');
    else
        assert(norm(effect_alloc-effect,Inf)<1e-8,'分配的加速度效果与 B_acc*u 不一致。');
    end
    residual=norm(effect_alloc-(vh+vc),Inf); max_residual=max(max_residual,residual);
    fprintf('%s residual=%.4g allocated=%s\n',method,residual,mat2str(effect_alloc',4));
    results.(char(method))=struct('command',command,'effect',effect,'allocated_effect',effect_alloc,'residual',residual,'info',info);
end
% 单舵失效/限幅映射：把第 3 列锁零，分配器必须保持该列零。
fault=model; fault.command_lower(3)=model.trim_delta_rad(3); fault.command_upper(3)=model.trim_delta_rad(3);
fault_ok=false(1,numel(methods)); fault_error=strings(1,numel(methods));
for j=1:numel(methods)
    try
        [command,~]=ca_allocate(methods(j),[0;0;0],[0;0;0],model.trim_delta_rad,fault,cfg_alloc,timing);
        fault_ok(j)=abs(command(3)-model.trim_delta_rad(3))<1e-7;
        fprintf('FAULT %s ok=%d cmd3=%.6f\n',methods(j),fault_ok(j),command(3));
    catch problem
        fault_error(j)=string(problem.identifier);
        if strlength(fault_error(j))==0, fault_error(j)=string(problem.message); end
        fprintf('FAULT_FAIL %s %s（记录为失败，不计入通过）\n',methods(j),fault_error(j));
    end
end
assert(all(fault_ok([1 3 4 5])),'WLS/PCA/DCA 未保持第3舵卡死值。');
assert(~fault_ok(2),'DA_NS 故障结果必须如实记录为失败。');
rank_full=rank(model.acceleration_matrix);
rank_without3=rank(model.acceleration_matrix(:,[1 2 4 5 6]));
% 执行器每列独立：单列阶跃不应改变其他列的目标。
held=model.trim_delta_rad; cmd=held; cmd(4)=cmd(4)+deg2rad(2);
step=ca_actuator_step(held,cmd,cfg_alloc.tau_model_s,0.002,deg2rad(cfg_alloc.rate_limit_deg_s));
delta=step-held; delta(4)=0;
assert(norm(delta,Inf)<1e-12,'执行器单列阶跃串到其他列。');
report=struct('methods',methods,'results',results,'max_residual',max_residual, ...
    'fault_column',3,'fault_ok',fault_ok,'fault_error',fault_error, ...
    'rank_full',rank_full,'rank_without_column3',rank_without3);
outdir=fullfile(root,'results','validation'); if ~isfolder(outdir), mkdir(outdir); end
save(fullfile(outdir,'shc09_b_frame_allocation.mat'),'report');
fprintf('b 系五种分配器接口、效果、限幅与第3列故障映射通过；最大残差=%.3g。\n',max_residual);
end
