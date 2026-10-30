function report = test_comparison()
% 检查冻结输入、最优性参照、优先级条件、异步时钟和原两组回归。
folder=ca_setup();
cfg=ca_validate_config(ca_config());
% 旧两组回归显式锁定原恢复算法，新恢复由专项测试覆盖。
cfg.predictive_restore_mode="legacy_norm";
cfg.measurement_mode="ideal";
cfg.plant_model="hover_linear";
model=ca_model(cfg);
% 检查扰动的开始时刻、轴向和正弦幅值，不把已知扰动直接输入分配器。
disturbed=cfg;
disturbed.disturbance_start_s=2;
disturbed.disturbance_amplitude_nm=[0.6;0.6;0];
disturbed.disturbance_bias_nm=[0.1;0;0];
assert(norm(ca_disturbance_torque(1.9,disturbed))==0,'扰动提前接入。');
assert(norm(ca_disturbance_torque(2,disturbed)-[0.1;0;0])<1e-12,'扰动接入偏置错误。');
assert(norm(ca_disturbance_torque(2.5,disturbed)-[0.7;0;0])<1e-12,'正弦扰动频率或幅值错误。');
B=model.acceleration_matrix;
timing=ca_pwm_timing(0.0007,cfg,zeros(6,1));
options=optimoptions('linprog','Display','none');
least_options=optimoptions('lsqlin','Display','none','OptimalityTolerance',1e-10);
% 冻结案例由共同动态可达范围构造，不根据某个闭环的结果挑选。
g=1-exp(-timing.hold_s./cfg.tau_model_s);
dynamic_capacity=B*(g.*min(model.command_upper,cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s)));
cases={"reachable",zeros(3,1),0.1*dynamic_capacity,zeros(6,1); ...
    "tracking_limited",0.25*dynamic_capacity,2*dynamic_capacity,zeros(6,1); ...
    "compensation_unreachable",2*dynamic_capacity,dynamic_capacity,zeros(6,1); ...
    "zero_tracking",0.1*dynamic_capacity,zeros(3,1),zeros(6,1); ...
    "nonzero_state",zeros(3,1),zeros(3,1),deg2rad(35)*ones(6,1)};
rows={};
samples=cell(size(cases,1),1);
for c=1:size(cases,1)
    vh=cases{c,2}; vc=cases{c,3}; delta=cases{c,4};
    at=ca_actuator_step(delta,timing.held_command,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
    lower=ca_actuator_step(at,model.command_lower,cfg.tau_model_s,timing.hold_s,deg2rad(cfg.rate_limit_deg_s));
    upper=ca_actuator_step(at,model.command_upper,cfg.tau_model_s,timing.hold_s,deg2rad(cfg.rate_limit_deg_s));
    [~,~,compflag]=linprog(zeros(6,1),[],[],B,vh,lower,upper,options);
    [~,~,totalflag]=linprog(zeros(6,1),[],[],B,vh+vc,lower,upper,options);
    samples{c}=struct('name',cases{c,1},'v_h',vh,'v_c',vc,'delta_hat',delta, ...
        'timing',timing,'compensation_reachable',compflag>0,'total_reachable',totalflag>0);
    for method=cfg.methods
        [u,info]=ca_allocate(method,vh,vc,delta,model,cfg,timing);
        assert(all(u>=model.command_lower-1e-7 & u<=model.command_upper+1e-7),'冻结案例超限。');
        if startsWith(method,'PCA') && info.mode==0
            assert(info.equality_error<cfg.constraint_tolerance,'PCA优先级等式错误。');
        end
        if method=="DCA"
            baseline=ca_actuator_step(delta,timing.held_command,cfg.tau_model_s,1/cfg.pwm_hz,deg2rad(cfg.rate_limit_deg_s));
            assert(norm(model.inertia*(B*info.native_predicted_delta-vh-vc)) ...
                <=norm(model.inertia*(B*baseline-vh-vc))+1e-7,'DCA优化比可行保持指令更差。');
        end
        if method=="PCA_PREDICTIVE" && cases{c,1}=="tracking_limited"
            assert(info.mode==0 && info.lambda<1-1e-5 && info.lambda>0,'未正确处理补偿可达、跟踪受限案例。');
        end
        rows(end+1,:)={char(cases{c,1}),char(method),compflag>0,totalflag>0,info.mode, ...
            info.lambda,info.beta,info.common_residual,info.priority_distance}; %#ok<AGROW>
        samples{c}.(method)=struct('command',u,'info',info);
    end
end

% 直接分配和零空间迭代覆盖伪逆超限输入，检查输出方向及物理约束。
rng(29);
nullspace_cases=0;
for k=1:80
    target=B*(2*model.command_upper.*randn(6,1));
    [u,info]=ca_da_ns(target,B,model,cfg);
    assert(norm(cross(B*u,target))<1e-6*max(1,norm(target)^2),'直接分配改变了总需求方向。');
    assert(all(u>=model.command_lower-1e-7 & u<=model.command_upper+1e-7),'零空间修正超限。');
    if info.mode==0
        assert(norm(B*u-min(1,info.direction_scale)*target,Inf)<1e-7,'零空间修正改变了已分配力矩。');
    end
    nullspace_cases=nullspace_cases+(info.iterations>0 && norm(pinv(B)*(info.direction_scale*target),Inf)>max(model.command_upper));
end
assert(nullspace_cases>0,'未覆盖伪逆超限的零空间修正分支。');

% WLS以独立求解器检查目标函数，而非仅检查返回值等于实现自身。
for weights={[10;10;1],[1000;1000;1]}
    trial=cfg; trial.wls_axis_weights=weights{1};
    for k=1:12
        delta=(2*rand(6,1)-1).*model.command_upper;
        target=B*(2*randn(6,1).*model.command_upper);
        [u,info]=ca_wls(target,B,delta,model,trial);
        axis_scale=sum(abs(B).*model.command_upper',2);
        Wv=diag(trial.wls_axis_weights./axis_scale);
        Wu=trial.wls_input_weight*diag(1./model.command_upper);
        A=[sqrt(trial.wls_gamma)*Wv*B;Wu];
        b=[sqrt(trial.wls_gamma)*Wv*target;zeros(6,1)];
        factor=norm(A,'fro');
        [reference,~,~,flag]=lsqlin(A/factor,b/factor,[],[],[],[],model.command_lower,model.command_upper,[],least_options);
        assert(flag>0 && info.exitflag>0,'WLS或独立验证求解器未收敛。');
        assert(norm(A*u-b)^2<=norm(A*reference-b)^2+1e-6*max(1,norm(A*reference-b)^2),'WLS未达到独立验证的目标函数值。');
    end
end

% 与原两组使用同一参考、配置和物理模型，确认独立副本未改变已有行为。
legacy_folder=fullfile(folder,'tests','legacy_reference');
addpath(legacy_folder);
legacy_cleanup=onCleanup(@()rmpath(legacy_folder)); %#ok<NASGU>
legacy_model=shc09_prediction_model(cfg);
assert(norm(legacy_model.torque_matrix-model.torque_matrix,Inf)<1e-12,'SHC09物理模型与源实现不同。');
short=cfg; short.duration_s=0.2; short.envelope_ramp_s=0.05;
short.save_results=false; short.save_figures=false;
for phase=[0,0.0007]
    short.pwm_phase_s=phase;
    ref=ca_reference(short);
    logs=cell(1,5);
    for k=1:numel(cfg.methods)
        logs{k}=ca_simulate(model,short,ref,cfg.methods(k));
        expected=phase+(0:floor((short.duration_s-phase)*short.pwm_hz))'/short.pwm_hz;
        assert(max(abs(logs{k}.pwm_update_time_s-expected))<1e-11,'PWM事件时钟错误。');
        checked=logs{k}.pwm_prediction_checked;
        assert(max(abs(logs{k}.pwm_end_prediction_error_rad(checked,:)),[],'all')<1e-10,'共同终点预测与匹配模型实际响应不符。');
    end
    for k=1:2
        legacy=shc09_simulate_attitude(legacy_model,short,ref,k==2);
        current=logs{k+3};
        assert(max(abs(legacy.command_rad-current.command_rad),[],'all')<1e-9,'两种PCA未复现原指令。');
        assert(max(abs(legacy.euler_rad-current.euler_rad),[],'all')<1e-10,'两种PCA未复现原闭环。');
    end
end
report=cell2table(rows,'VariableNames',{'case_name','method','compensation_reachable','total_reachable', ...
    'mode','lambda','beta','common_residual','priority_distance'});
out=fullfile(folder,'results','validation');
if ~isfolder(out), mkdir(out); end
writetable(report,fullfile(out,'frozen_inputs.csv'),'Encoding','UTF-8');
save(fullfile(out,'frozen_inputs.mat'),'samples','cfg','model');
fprintf('冻结输入、零空间、WLS独立最优性、PWM时钟和旧两组回归检查全部通过。\n');
% 半周期只改变内部预测时刻，真实保持终点及其公共预测仍必须一致。
half=short;
half.predictive_horizon_fraction=0.5;
half.duration_s=0.05;
half.envelope_ramp_s=0.01;
half.roll_amplitude_deg=0;
half.pitch_amplitude_deg=0;
half.yaw_amplitude_deg=0.001;
reference=ca_reference(half);
halflog=ca_simulate(model,half,reference,"PCA_PREDICTIVE");
checked=halflog.pwm_prediction_checked;
assert(max(abs(halflog.pwm_end_prediction_error_rad(checked,:)),[],'all')<1e-10, ...
    '半周期分配改变了公共完整周期终点预测的一致性。');
assert(max(abs(halflog.native_horizon_s-half.predictive_horizon_fraction/half.pwm_hz ...
    -halflog.prediction_delay_s))<1e-12,'半周期原生预测时刻记录错误。');
end
