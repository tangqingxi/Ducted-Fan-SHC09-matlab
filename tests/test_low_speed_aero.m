function report = test_low_speed_aero()
% 用上一轮冻结源码核对逐位兼容，并独立量化边界跳变及真值接口。
root=ca_setup(); fixtures=fullfile(root,'tests','fixtures'); addpath(fixtures);
cleanup=onCleanup(@()rmpath(fixtures)); %#ok<NASGU>
cfg=ca_validate_config(ca_config()); model=ca_model(cfg); p=model.parameters;
assert(cfg.aero_low_speed_model=="legacy",'默认配置必须保留旧低速模型。');
rng(7341); worst=0;
for k=1:60
    state=ca_plant_init(model);
    state.rotation=ca_euler_rotation(0.3*randn(3,1)); state.velocity=(0.01+3*rand)*randn(3,1);
    fixed=[0,0.5,2]; if k<=3, state.velocity=[0;0;fixed(k)]; end
    state.delta=deg2rad(40)*(2*rand(6,1)-1); state.motor=200+1000*rand; state.omega=randn(3,1);
    a=ca_shc09_aerodynamics(state.rotation,state.velocity,state.omega,state.delta,state.motor,model,cfg);
    b=ca_shc09_aerodynamics_round1(state.rotation,state.velocity,state.omega,state.delta,state.motor,model,cfg);
    for name=reshape(string(fieldnames(b)),1,[])
        assert(isequaln(a.(name),b.(name)),'legacy物理输出不逐位相同：%s',name);
        if isnumeric(a.(name)), worst=max(worst,max(abs(a.(name)-b.(name)),[],'all')); end
    end
end
hold=cfg; hold.aero_low_speed_model="hold_90"; hold.aero_extrapolation_policy="error";
state=ca_plant_init(model); state.velocity=[0;0;0.5];
a=ca_plant_outputs(state,model,hold,0);
assert(a.duct_angle_rad==pi/2 && ~a.table_extrapolated && a.low_speed_regularized,'低速正则化未生效。');
state.velocity=[0;1.5;0]; a=ca_plant_outputs(state,model,hold,0); b=ca_plant_outputs(state,model,cfg,0);
assert(a.duct_angle_rad==b.duct_angle_rad,'过渡区改变了严格门禁使用的原始迎角。');
for speed=[1+1e-6,1.5,2]
    state.velocity=[0;0;speed]; rejected=false;
    try, ca_plant_outputs(state,model,hold,0); catch problem, rejected=strcmp(problem.identifier,'ca:AeroTableDomain'); end
    assert(rejected,'阈值外及平滑过渡区的表外迎角未触发严格门禁。');
end
boundary=[];
for motor=[200,model.hover_motor_rad_s,1200]
    for angle=0:5:130
        state.motor=motor; direction=[0;sind(angle);-cosd(angle)];
        state.velocity=(1-1e-6)*direction; a=ca_plant_outputs(state,model,hold,0);
        state.velocity=(1+1e-6)*direction; b=ca_plant_outputs(state,model,hold,0);
        force=norm(a.force_body_n-b.force_body_n); moment=norm(a.torque_body_nm-b.torque_body_nm);
        boundary(end+1,:)=[motor,angle,force,moment,100*force/(p.m*p.g),100*moment/p.l1/(p.m*p.g)]; %#ok<AGROW>
    end
end
assert(max(boundary(:,5))<2,'正则化边界力差仍超过重量的百分之二。');
nominal=ca_allocator_config(cfg); changed=hold; changed.aero_low_speed_m_s=0.5;
assert(isequaln(nominal,ca_allocator_config(changed)) && isequaln(model,ca_model(changed)), ...
    '低速真实参数进入名义配置或模型。');
assert(~any(startsWith(string(fieldnames(nominal)),["aero_","vane_"])),'真实字段进入分配器。');
for value={-1,3,NaN,Inf,[1,2]}
    trial=cfg; trial.aero_low_speed_m_s=value{1}; rejected=false;
    try, ca_validate_config(trial); catch problem, rejected=strcmp(problem.identifier,'ca:AeroLowSpeed'); end
    assert(rejected,'非法低速阈值未被拒绝。');
end
trial=cfg; trial.aero_low_speed_model="unknown"; rejected=false;
try, ca_validate_config(trial); catch problem, rejected=strcmp(problem.identifier,'ca:AeroLowSpeed'); end
assert(rejected,'非法低速模型未被拒绝。');
report=struct('legacy_states',60,'legacy_max_difference',worst,'boundary',array2table(boundary, ...
    'VariableNames',{'motor_rad_s','angle_deg','force_jump_n','moment_jump_nm','force_weight_percent','moment_equivalent_force_weight_percent'}), ...
    'max_boundary_force_weight_percent',max(boundary(:,5)),'blend_interval_m_s',[1,2]);
fprintf('低速模型：六十个legacy状态逐位一致；平滑后最大边界力差%.8g%%重量；高速门禁通过。\n',max(boundary(:,5)));
end
