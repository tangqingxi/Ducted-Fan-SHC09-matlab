function report = run_noncollinear_study()
% 统一冻结状态下考察非共线需求；保留全部六种轴向组合，避免只展示有利方向。
folder=ca_setup();
out=fullfile(folder,'results','noncollinear_study');
assert(~isfolder(out),'非共线研究目录已存在，请保留旧结果后另设目录。');
mkdir(out);
cfg=ca_validate_config(ca_config());
cfg.plant_model="hover_linear";
model=ca_model(cfg);
B=model.acceleration_matrix;
options=optimoptions('linprog','Display','none');
capacity=zeros(3,1);
% 求纯轴控制作用的静态最大值，需求按模型能力归一化，不按算法结果选取。
for axis=1:3
    other=setdiff(1:3,axis);
    [u,~,flag]=linprog(-B(axis,:)',[],[],B(other,:),zeros(2,1), ...
        model.command_lower,model.command_upper,options);
    assert(flag>0,'纯轴能力求解失败。');
    capacity(axis)=B(axis,:)*u;
end
pairs=[1,2;1,3;2,1;2,3;3,1;3,2];
names=["roll","pitch","yaw"];
rows={};
certificates=struct();
static_capacity=capacity;
for family=1:2
capacity=static_capacity;
if family==2
    % 第二类在零舵角下突然出现补偿需求，按保守动态可达集合构造可实现需求。
    g=1-exp(-1/cfg.pwm_hz./cfg.tau_model_s);
    endpoint_bound=g.*min(model.command_upper,cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    for axis=1:3
        other=setdiff(1:3,axis);
        [endpoint,~,flag]=linprog(-B(axis,:)',[],[],B(other,:),zeros(2,1), ...
            -endpoint_bound,endpoint_bound,options);
        assert(flag>0,'动态纯轴能力求解失败。');
        capacity(axis)=B(axis,:)*endpoint;
    end
end
for k=1:size(pairs,1)
    comp=pairs(k,1);
    track=pairs(k,2);
    vh=zeros(3,1); vh(comp)=0.55*capacity(comp);
    vc=zeros(3,1); vc(track)=1.4*capacity(track);
    delta=pinv(B)*vh;
    if family==2, delta=zeros(6,1); end
    assert(all(delta>=model.command_lower & delta<=model.command_upper),'初始配平状态超限。');
    % 先存在稳定补偿偏角，再提出与其正交的过大跟踪需求。
    timing=ca_pwm_timing(0.0007,cfg,delta);
    rate=deg2rad(cfg.rate_limit_deg_s);
    at=ca_actuator_step(delta,delta,cfg.tau_model_s,timing.delay_s,rate);
    lower=ca_actuator_step(at,model.command_lower,cfg.tau_model_s,timing.hold_s,rate);
    upper=ca_actuator_step(at,model.command_upper,cfg.tau_model_s,timing.hold_s,rate);
    [compwitness,~,compflag]=linprog(zeros(6,1),[],[],B,vh,lower,upper,options);
    [~,~,totalflag]=linprog(zeros(6,1),[],[],B,vh+vc,lower,upper,options);
    assert(compflag>0 && totalflag==-2,'案例未满足补偿可达、总需求不可达，或求解器未给出明确结论。');
    prefix="trim_";
    if family==2, prefix="onset_"; end
    label=prefix+names(comp)+"_comp_"+names(track)+"_track";
    item=struct('v_h',vh,'v_c',vc,'delta_hat',delta,'held_command',delta, ...
        'timing',timing,'compensation_reachable',true,'total_reachable',false, ...
        'reachable_lower',lower,'reachable_upper',upper,'axis_capacity',capacity, ...
        'compensation_witness',compwitness,'compensation_exitflag',compflag,'total_exitflag',totalflag);
    for method=cfg.methods
        [u,info]=ca_allocate(method,vh,vc,delta,model,cfg,timing);
        actual=ca_actuator_step(at,u,cfg.tau_model_s,timing.hold_s,rate);
        effect=B*actual;
        comp_ratio=effect(comp)/vh(comp);
        track_ratio=effect(track)/vc(track);
        % 在归一化三轴坐标下计算到优先级线段的距离，不称为物理补偿误差。
        normalized_c=vc./capacity;
        normalized_difference=(effect-vh)./capacity;
        projection=min(1,max(0,normalized_c'*normalized_difference/(normalized_c'*normalized_c)));
        distance=norm(normalized_difference-projection*normalized_c);
        total_residual=norm((effect-vh-vc)./capacity);
        rows(end+1,:)={char(label),char(method),comp_ratio,track_ratio,distance,total_residual, ...
            info.lambda,info.mode,max(abs(rad2deg(u)))}; %#ok<AGROW>
        item.(method)=struct('command',u,'info',info,'evaluated_effect',effect);
        if method=="PCA_PREDICTIVE"
            assert(info.mode==0 && info.lambda<1 && abs(comp_ratio-1)<1e-7 ...
                && distance<1e-7,'预测PCA未满足正常补偿优先关系。');
        end
    end
    certificates.(label)=item;
end
end
report=cell2table(rows,'VariableNames',{'case_name','method','compensation_axis_projection_ratio', ...
    'tracking_axis_projection_ratio','normalized_priority_distance','normalized_total_residual', ...
    'native_lambda','mode','max_command_deg'});
writetable(report,fullfile(out,'comparison.csv'));
save(fullfile(out,'frozen_inputs.mat'),'certificates','cfg','model','static_capacity','report');
plot_noncollinear_study(report,cfg,out);
disp(report);
end
