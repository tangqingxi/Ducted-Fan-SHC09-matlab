function report = test_vane_mismatch()
% 独立参考方程、解析导数、真值接口与中性闭环回归共同验证对象失配。
root=ca_setup(); cfg=ca_validate_config(ca_config()); model=ca_model(cfg); p=model.parameters;
reference=fullfile(root,'models','shc09','reference'); addpath(reference);
cleanup=onCleanup(@()rmpath(reference)); %#ok<NASGU>
d=load(fullfile(reference,'duct_raw.mat')); w=load(fullfile(reference,'wing_raw.mat'));
source=Initialized_SHC09(d.duct_raw,w.wing_raw,p.g,pi/180); env=struct('g',p.g,'den',p.den);
rng(1234); errors=zeros(40,3);
legacy=rmfield(cfg,{'vane_gain_scale','vane_deflection_map','vane_saturation_deg'});
for k=1:40
    angles=deg2rad(30)*(2*rand(3,1)-1); state=ca_plant_init(model);
    state.rotation=ca_euler_rotation(angles); state.velocity=6*(2*rand(3,1)-1);
    state.omega=2*(2*rand(3,1)-1); state.delta=deg2rad(40)*(2*rand(6,1)-1); state.motor=650+400*rand;
    trial=cfg; trial.wind_ned_m_s=2*(2*rand(3,1)-1);
    trial.external_force_ned_n=randn(3,1); trial.disturbance_torque_nm=0.01*randn(3,1);
    dist=struct('Dx',trial.wind_ned_m_s(1),'Dy',trial.wind_ned_m_s(2),'Dz',trial.wind_ned_m_s(3), ...
        'Fx',trial.external_force_ned_n(1),'Fy',trial.external_force_ned_n(2),'Fz',trial.external_force_ned_n(3), ...
        'Mx',trial.disturbance_torque_nm(1),'My',trial.disturbance_torque_nm(2),'Mz',trial.disturbance_torque_nm(3));
    actuator=struct('u',state.delta,'omega_m',state.motor);
    [dx,force,source_state]=SHC09_Sys(0,[state.position;state.velocity;angles;state.omega],source,env,actuator,dist,struct(),struct());
    out=ca_plant_outputs(state,model,trial,0);
    errors(k,:)=[norm(dx(4:6)-out.acceleration_ned_m_s2,Inf),norm(dx(10:12)-out.alpha_rad_s2,Inf), ...
        abs(source_state.Ve-out.exit_speed_m_s)];
    assert(norm(out.force_body_n+state.rotation'*trial.external_force_ned_n-[force.Fx;force.Fy;force.Fz],Inf)<1e-11, ...
        '参考非重力力不一致。');
    missing=rmfield(trial,{'vane_gain_scale','vane_deflection_map','vane_saturation_deg'});
    assert(isequaln(out,ca_plant_outputs(state,model,missing,0)),'缺省配置与显式M0不一致。');
end
assert(max(errors,[],'all')<1e-10,'中性物理方程未保持参考一致性。');
state=ca_plant_init(model); state.velocity=[1;2;-0.5];
base=ca_plant_outputs(state,model,cfg,0);
trial=cfg; trial.vane_gain_scale=[1.2;0.8;1.2;0.8;1.2;0.8];
changed=ca_plant_outputs(state,model,trial,0);
assert(isequal(changed.actual_torque_matrix,base.actual_torque_matrix*diag(trial.vane_gain_scale)), ...
    '真实效能矩阵未按列缩放。');
assert(isequaln(ca_model(trial),model),'真实失配污染了名义模型。');
assert(~any(startsWith(string(fieldnames(model)),"vane_")),'分配器可见模型带入真实舵效。');
for mapping=["tanh","stall"]
    trial.vane_gain_scale=ones(6,1); trial.vane_deflection_map=mapping;
    for channel=1:6
        state.delta=zeros(6,1); state.delta(channel)=deg2rad(40);
        nonlin=ca_plant_outputs(state,model,trial,0); linear=ca_plant_outputs(state,model,cfg,0);
        assert(norm(nonlin.torque_body_nm-nonlin.passive_torque_body_nm) ...
            <norm(linear.torque_body_nm-linear.passive_torque_body_nm),'大偏角未减小舵面力矩。');
    end
    state.delta=deg2rad([12;-16;20;-24;28;-32]);
    nonlin=ca_plant_outputs(state,model,trial,0);
    for channel=1:6
        plus=state; minus=state; plus.delta(channel)=plus.delta(channel)+1e-6; minus.delta(channel)=minus.delta(channel)-1e-6;
        a=ca_plant_outputs(plus,model,trial,0); b=ca_plant_outputs(minus,model,trial,0);
        numerical=(a.torque_body_nm-b.torque_body_nm)/2e-6;
        expected=base.actual_torque_matrix(:,channel)*nonlin.vane_incremental_gain(channel);
        assert(norm(numerical-expected,Inf)<1e-9,'真实力矩局部导数错误。');
    end
    state.delta=2*p.cm*ones(6,1); high=ca_plant_outputs(state,model,trial,0);
    state.delta=p.cm*ones(6,1); clipped=ca_plant_outputs(state,model,trial,0);
    assert(isequaln(high,clipped),'非线性映射未在原限幅之后应用。');
end
expected=["sample_hz","pwm_hz","pwm_phase_s","tau_model_s","rate_limit_deg_s", ...
    "max_iterations","constraint_tolerance","wls_axis_weights","wls_gamma","wls_input_weight", ...
    "dca_horizon_s","predictive_horizon_fraction","predictive_restore_mode"];
nominal=ca_allocator_config(cfg);
assert(isequal(sort(string(fieldnames(nominal))),sort(expected(:))),'分配器白名单字段改变。');
for forbidden=["vane_","tau_actual","actuator_tau_variation","disturbance","bias"]
    assert(~any(contains(string(fieldnames(nominal)),forbidden)),'真实参数进入分配器接口。');
end
trial=cfg; trial.vane_gain_scale=[1;1;0.7;1;1;1]; trial.vane_deflection_map="stall";
trial.tau_actual_s=0.05*ones(6,1); trial.actuator_tau_variation_enabled=true;
assert(isequaln(ca_allocator_config(trial),nominal) && isequaln(ca_model(trial),model),'真实参数污染名义接口。');
timing=ca_pwm_timing(0.0007,cfg,model.trim_delta_rad);
for method=cfg.methods
    a=ca_allocate(method,[0;0;10],[1;2;3],model.trim_delta_rad,model,nominal,timing);
    b=ca_allocate(method,[0;0;10],[1;2;3],model.trim_delta_rad,ca_model(trial),ca_allocator_config(trial),timing);
    assert(isequal(a,b),'真实参数改变了冻结输入分配命令。');
end
invalids={"vane_gain_scale",zeros(6,1);"vane_gain_scale",ones(5,1);"vane_gain_scale",[ones(5,1);Inf]; ...
    "vane_gain_scale",[ones(5,1);NaN];"vane_gain_scale",-ones(6,1);"vane_gain_scale",ones(2,3); ...
    "vane_deflection_map","other";"vane_deflection_map",["linear","stall"]; ...
    "vane_saturation_deg",19;"vane_saturation_deg",41;"vane_saturation_deg",NaN;"vane_saturation_deg",[28,28]};
for k=1:size(invalids,1)
    trial=cfg; trial.(invalids{k,1})=invalids{k,2}; rejected=false;
    try, ca_validate_config(trial); catch problem, rejected=startsWith(problem.identifier,'ca:Vane'); end
    assert(rejected,'非法真实舵效配置未被拒绝。');
end
validated=ca_validate_config(legacy);
assert(isequal(validated.vane_gain_scale,ones(6,1)) && validated.vane_deflection_map=="linear",'旧配置缺省失效。');
report=struct('reference_max_error',max(errors,[],1),'random_states',40,'invalid_configs',size(invalids,1), ...
    'allocator_fields',fieldnames(nominal),'nominal_B_unchanged',true,'frozen_all_five_identical',true);
fprintf('对象舵效：四十个参考状态、非线性导数、限幅、名义B及白名单隔离和非法配置检查通过。\n');
end
