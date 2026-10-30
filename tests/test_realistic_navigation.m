function report = test_realistic_navigation()
% 独立检查真实参数隔离、带偏置定位对控制指令的影响和官方导航有效性。
root=ca_setup(); cfg=ca_config(); cfg.navigation_mode="ideal";
cfg=ca_validate_config(cfg); model=ca_model(cfg); B=model.acceleration_matrix;
timing=ca_pwm_timing(0.0007,cfg,zeros(6,1)); vh=[0;0;2]; vc=[1;2;0];
changed=cfg; changed.tau_actual_s=[0.01;0.02;0.04;0.06;0.08;0.1]; changed.actuator_tau_variation_enabled=true;
maximum_command_difference=0;
for method=cfg.methods
    [u,~]=ca_allocate(method,vh,vc,zeros(6,1),model,cfg,timing);
    [v,~]=ca_allocate(method,vh,vc,zeros(6,1),model,changed,timing);
    difference=norm(u-v,Inf); maximum_command_difference=max(maximum_command_difference,difference);
    assert(difference<1e-12,'分配器读取了真实时间常数。');
end
first=ca_true_actuator_tau(0,changed); later=ca_true_actuator_tau(5,changed);
assert(norm(first-later,Inf)>1e-3 && all(first>0) && all(later>0),'真实舵机缓变未生效。');
cfg.navigation_mode="px4_ecl"; cfg.flight_mode="position_hold";
cfg.initial_position_ned_m=[0;0;-10]; cfg.position_reference_ned_m=cfg.initial_position_ned_m;
cfg.duration_s=1/cfg.sample_hz; cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.gnss_position_bias_m=zeros(3,1); cfg=ca_validate_config(cfg);
ref=ca_reference(cfg); experiment=ca_prepare_experiment(cfg,ref.time_s);
before=ca_simulate(model,cfg,ref,"WLS",experiment);
biased=cfg; biased.gnss_position_bias_m=[1.5;-1;0];
after=ca_simulate(model,biased,ref,"WLS",experiment);
assert(isequal(before.position_ned_m(1,:),after.position_ned_m(1,:)),'定位偏置改变了初始物理真值。');
estimate_shift=after.estimated_position_ned_m(1,:)-before.estimated_position_ned_m(1,:);
assert(norm(estimate_shift(1:2)-[1.5,-1],Inf)<0.05,'官方滤波器未融合有偏置GNSS。');
desired_change=norm(after.desired_euler_rad(1,:)-before.desired_euler_rad(1,:),Inf);
assert(desired_change>0.05 && norm(after.command_rad(1,:)-before.command_rad(1,:),Inf)>1e-3, ...
    '控制器仍在用位置真值或定位估计未进入闭环。');
assert(all(before.navigation_health(:,1:5),'all') && all(after.navigation_health(:,1:5),'all'), ...
    '官方导航未对准或失去融合。');
Q=[0,1,0;-1,0,0;0,0,1];
assert(norm(Q*Q'-eye(3),Inf)<1e-12 && det(Q)==1,'SHC09到FRD坐标映射不正交。');
R=ca_quaternion_rotation([sqrt(0.5);0;0;sqrt(0.5)])*Q;
assert(norm(R-eye(3),Inf)<1e-12,'FRD航向90度没有还原SHC09零姿态。');
report=struct('maximum_allocator_command_change_when_only_true_tau_changes_rad',maximum_command_difference, ...
    'gnss_bias_estimate_shift_m',estimate_shift,'desired_attitude_change_rad',desired_change, ...
    'official_ekf_valid',true,'frame_mapping_passed',true);
save(fullfile(root,'results','validation','realistic_navigation.mat'),'report','cfg','before','after');
disp(report);
end
