function report = test_b_frame_real_layout()
% 只读式第一阶段验证：真实 b 系几何、B/J、单舵方向、边界转换和参考转换。
root=ca_setup();
cfg=ca_validate_config(ca_config());
model=ca_model(cfg); p=model.parameters;
R=p.R_old_to_b;
C=[0,1,0;-1,0,0;0,0,1]; % FRD -> b
P_sdf=[-1,-.5,.5,1,.5,-.5;0,sqrt(3)/2,sqrt(3)/2,0,-sqrt(3)/2,-sqrt(3)/2;1,1,1,1,1,1];
P_old=[0,-sqrt(3)/2,-sqrt(3)/2,0,sqrt(3)/2,sqrt(3)/2;-1,-.5,.5,1,.5,-.5;1,1,1,1,1,1];
assert(string(model.coordinate_frame)=="b");
assert(norm(p.P_cs-P_old,'fro')==0);
assert(norm(p.P_cs_b-R*P_old,'fro')==0);
assert(norm(p.P_cs_b-C*P_sdf,'fro')<1e-12);
assert(norm(p.J_b-diag([0.0436,0.0438,0.005006]),'fro')==0);
assert(norm(model.inertia-p.J_b,'fro')==0);
assert(norm(model.acceleration_matrix-p.J_b\model.torque_matrix,'fro')==0);
theta=deg2rad(0:60:300);
expected=[p.l1*cos(theta(:)),p.l1*sin(theta(:)),p.l2*ones(6,1)];
assert(norm(model.hinges_b-expected,'fro')<1e-14);
for i=1:6
    assert(abs(norm(model.hinges_b(i,1:2))-p.l1)<1e-14);
    assert(abs(model.hinges_b(i,3)-p.l2)<1e-14);
end
assert(rank(model.torque_matrix)==3 && all(size(model.torque_matrix)==[3,6]));

% 单舵 +1/-1 deg 的力矩方向；只检查线性映射和反对称。
responses=zeros(6,3);
for i=1:6
    d=zeros(6,1); d(i)=deg2rad(1);
    plus=model.torque_matrix*d;
    minus=model.torque_matrix*(-d);
    assert(norm(plus+minus)<1e-15);
    responses(i,:)=plus';
end
assert(max(abs(responses(:,3)-p.l2*model.hover_exit_speed_m_s^2*p.d_cs*deg2rad(1)))<1e-15);

% 边界转换：b 状态输出应等于 R 乘旧原生系气动输出。
state=ca_plant_init(model);
state.rotation=ca_euler_rotation([0.03;-0.02;0.01]);
state.velocity=[1.3;2.2;0.5];
state.omega=[0.1;-0.2;0.15];
state.delta=deg2rad([5;-3;2;-4;1;6]);
state.motor=650;
trial=cfg; trial.wind_ned_m_s=[0.5;-0.2;0.1]; trial.external_force_ned_n=[0.1;0.2;-0.3];
trial.disturbance_torque_nm=[0.002;-0.001;0.003];
out=ca_plant_outputs(state,model,trial,0.4);
old=state; old.rotation=state.rotation*R; old.velocity=R'*state.velocity; old.omega=R'*state.omega;
aero=ca_shc09_aerodynamics(old.rotation,old.velocity,old.omega,old.delta,old.motor,model,trial);
assert(norm(out.force_body_n-R*aero.force_body_n)<1e-11);
assert(norm(out.torque_body_nm-R*aero.torque_body_nm)<1e-11);
assert(norm(out.actual_torque_matrix-R*aero.actual_torque_matrix)<1e-11);
assert(norm(out.airspeed_body_m_s-R*aero.airspeed_body_m_s)<1e-11);
expected_alpha=model.inertia\(out.torque_body_nm+R*ca_disturbance_torque(0.4,trial) ...
    -cross(state.omega,model.inertia*state.omega));
assert(norm(out.alpha_rad_s2-expected_alpha)<1e-11);

% 配平仍为零角加速度/平动加速度。
trim=ca_plant_init(model); trim_out=ca_plant_outputs(trim,model,cfg,0);
assert(norm(trim_out.alpha_rad_s2)<1e-9);
assert(norm(trim_out.acceleration_ned_m_s2)<1e-9);

% 参考转换：R_b=R_old*R'，body 向量左乘 R。
ref.rotation=ca_euler_rotation([0.1;-0.05;0.2]);
ref.rotation_ff=ref.rotation;
ref.omega_body_rad_s=[0.3;-0.2;0.1]';
ref.alpha_body_rad_s2=[0.4;-0.1;0.2]';
ref_b=ca_reference_to_b(ref,model);
assert(norm(ref_b.rotation-ref.rotation*R')<1e-14);
assert(norm(ref_b.omega_body_rad_s-ref.omega_body_rad_s*R')<1e-14);
assert(norm(ref_b.alpha_body_rad_s2-ref.alpha_body_rad_s2*R')<1e-14);

% 分配器接口：B 维度、加速度矩阵和零需求输出。
alloc_cfg=ca_allocator_config(cfg);
timing=ca_pwm_timing(0.0007,alloc_cfg,model.trim_delta_rad);
[cmd,info]=ca_allocate("WLS",[0;0;0],[0;0;0],model.trim_delta_rad,model,alloc_cfg,timing);
assert(all(size(cmd)==[6,1]) && all(isfinite(cmd)));
assert(all(size(info.allocated_effect)==[3,1]));

report=struct('frame',string(model.coordinate_frame),'P_cs_b',p.P_cs_b, ...
    'B_tau',model.torque_matrix,'B_acc',model.acceleration_matrix,'J_b',p.J_b, ...
    'hinges_b',model.hinges_b,'single_vane_1deg',responses, ...
    'boundary_force_error',norm(out.force_body_n-R*aero.force_body_n), ...
    'boundary_torque_error',norm(out.torque_body_nm-R*aero.torque_body_nm), ...
    'reference_rotation_error',norm(ref_b.rotation-ref.rotation*R'));
fprintf('b-frame geometry/B/J/single-vane/boundary/reference/allocator checks passed.\n');
disp(report);
outdir=fullfile(root,'results','validation'); if ~isfolder(outdir), mkdir(outdir); end
save(fullfile(outdir,'shc09_b_frame_phase1.mat'),'report');
end
