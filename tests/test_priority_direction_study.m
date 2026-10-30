function test_priority_direction_study()
% 用物理平衡和显式末端越界检查新协议，避免将均方误差小误当作完成任务。
ca_setup(); cfg=ca_validate_config(ca_config()); model=ca_model(cfg);
p=ca_priority_direction_protocol(cfg,model,0.8);
for k=1:3
    state=ca_plant_init(model,cfg); state.delta=p.witness_delta_rad(:,k);
    trial=cfg; trial.disturbance_torque_nm=p.external_nm(:,k);
    out=ca_plant_outputs(state,model,trial,0);
    assert(norm(out.alpha_rad_s2,Inf)<1e-10 && norm(out.acceleration_ned_m_s2,Inf)<1e-10, ...
        '方向标定与真实悬停物理平衡不一致。');
    assert(all(abs(state.delta)<=0.8*model.command_upper+1e-9),'标定没有保留名义舵角余量。');
end
for alpha=linspace(0,1,11)
    state=ca_plant_init(model,cfg); state.delta=(1-alpha)*p.witness_delta_rad(:,1)+alpha*p.witness_delta_rad(:,2);
    trial=cfg; trial.disturbance_torque_nm=(1-alpha)*p.external_nm(:,1)+alpha*p.external_nm(:,2);
    out=ca_plant_outputs(state,model,trial,0);
    assert(norm(out.alpha_rad_s2,Inf)<1e-10,'方向切换的中间补偿不满足物理平衡。');
end
% 纯分析样本：最后一个末端采样越界，均方值虽小也不能计为整段合格。
cfg.sample_hz=20; t=(0:1/cfg.sample_hz:40)'; n=numel(t);
ref=struct('time_s',t,'position_ned_m',zeros(n,3),'euler_rad',zeros(n,3));
log=struct('position_ned_m',zeros(n,3),'velocity_ned_m_s',zeros(n,3),'euler_rad',zeros(n,3), ...
    'omega_rad_s',zeros(n,3),'omega_reference_rad_s',zeros(n,3),'euler_error_rad',zeros(n,3), ...
    'pwm_update_time_s',t,'pwm_command_rad',zeros(n,6),'held_command_rad',zeros(n,6),'actual_delta_rad',zeros(n,6), ...
    'mode',zeros(n,1),'lambda',ones(n,1),'solver_exitflag',ones(n,1),'solver_rescue',false(n,1),'table_extrapolated',false(n,1));
index=find(t<28,1,'last'); log.position_ned_m(index,1)=0.21;
r=struct('config',cfg,'reference',ref,'model',model,'protocol',p,'scenario',"synthetic", ...
    'variants',struct('label','PCA_PREDICTIVE'),'logs',struct('PCA_PREDICTIVE',log));
[~,terminal]=ca_priority_direction_metrics(r);
assert(all(terminal.terminal_success(1:2)) && ~terminal.terminal_success(3),'末端完成判据没有检查全部采样。');
assert(abs(terminal.terminal_position_peak_m(3)-0.21)<1e-12 && terminal.terminal_position_rmse_m(3)<0.2,'末端指标定义错误。');
fprintf('三方向物理平衡、中间载荷可行性及末端完成判据通过。\n');
end
