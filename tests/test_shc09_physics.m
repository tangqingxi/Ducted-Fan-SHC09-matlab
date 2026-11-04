function report = test_shc09_physics()
% b 系物理回归：旧 SHC09_Sys 仅作为独立原生系参考，结果经 R 转 b 后比较。
folder=ca_setup();
cfg=ca_validate_config(ca_config());
model=ca_model(cfg); p=model.parameters; R=p.R_old_to_b;
reference=fullfile(folder,'models','shc09','reference');
addpath(reference);
cleanup=onCleanup(@()rmpath(reference));
d=load(fullfile(reference,'duct_raw.mat')); w=load(fullfile(reference,'wing_raw.mat'));
source=Initialized_SHC09(d.duct_raw,w.wing_raw,p.g,pi/180);
assert(norm(source.P_cs-p.P_cs,'fro')==0,'参考模型 P_cs 参数不一致。');
% 旧源用旧原生轴，必须给它坐标一致的 J（b 系 J_b 转回旧原生），
% 否则比较会把上一阶段的 J 轴序修正误判为坐标变换误差。
source.J=R'*p.J_b*R;
assert(norm(source.J-diag([0.0436,0.0438,0.005006]),'fro')==0,'旧源 J 转换不一致。');
P_sdf=[-1,-.5,.5,1,.5,-.5;0,sqrt(3)/2,sqrt(3)/2,0,-sqrt(3)/2,-sqrt(3)/2;1,1,1,1,1,1];
C=[0,1,0;-1,0,0;0,0,1];
assert(norm(p.P_cs_b-C*P_sdf,'fro')<1e-12,'b 系 P_cs 与 SDF 独立参考不一致。');
assert(norm(p.J_b-diag([0.0436,0.0438,0.005006]),'fro')==0,'J_b 轴序错误。');
B_independent=C*(p.d_cs*model.hover_exit_speed_m_s^2*diag([p.l1,p.l1,p.l2])*P_sdf);
assert(norm(model.torque_matrix-B_independent,'fro')<1e-12,'B_tau 与 SDF 独立构造不一致。');
assert(norm(model.acceleration_matrix-p.J_b\model.torque_matrix,'fro')==0);
Env=struct('g',p.g,'den',p.den);
rng(1234); errors=zeros(40,3);
for k=1:40
    angles=deg2rad(30)*(2*rand(3,1)-1);
    state=ca_plant_init(model);
    state.rotation=ca_euler_rotation(angles);
    state.velocity=6*(2*rand(3,1)-1);
    state.omega=2*(2*rand(3,1)-1);
    state.delta=deg2rad(40)*(2*rand(6,1)-1);
    state.motor=650+400*rand;
    trial=cfg; trial.wind_ned_m_s=2*(2*rand(3,1)-1);
    trial.external_force_ned_n=randn(3,1);
    trial.disturbance_torque_nm=0.01*randn(3,1);
    Dist=struct('Dx',trial.wind_ned_m_s(1),'Dy',trial.wind_ned_m_s(2),'Dz',trial.wind_ned_m_s(3), ...
        'Fx',trial.external_force_ned_n(1),'Fy',trial.external_force_ned_n(2),'Fz',trial.external_force_ned_n(3), ...
        'Mx',trial.disturbance_torque_nm(1),'My',trial.disturbance_torque_nm(2),'Mz',trial.disturbance_torque_nm(3));
    Actuator=struct('u',state.delta,'omega_m',state.motor);
    old=state; old.rotation=state.rotation*R; old.velocity=state.velocity; old.omega=R'*state.omega;
    old_angles=ca_rotation_euler(old.rotation);
    x=[old.position;old.velocity;old_angles;old.omega];
    [dx,force,source_state]=SHC09_Sys(0,x,source,Env,Actuator,Dist,struct(),struct());
    out=ca_plant_outputs(state,model,trial,0);
    errors(k,:)=[norm(dx(4:6)-out.acceleration_ned_m_s2,Inf), ...
        norm(R*dx(10:12)-out.alpha_rad_s2,Inf),abs(source_state.Ve-out.exit_speed_m_s)];
    sensor_force=out.force_body_n+state.rotation'*trial.external_force_ned_n;
    assert(norm(sensor_force-R*[force.Fx;force.Fy;force.Fz],Inf)<1e-10,'b 系比力与旧源变换不一致。');
end
assert(max(errors,[],'all')<1e-10,'b 系物理方程与旧源独立参考不一致。');
trim=ca_plant_init(model); out=ca_plant_outputs(trim,model,cfg,0);
assert(norm(out.alpha_rad_s2)<1e-9 && norm(out.acceleration_ned_m_s2)<1e-9,'悬停配平失败。');
assert(norm(model.acceleration_matrix-model.inertia\model.torque_matrix,'fro')==0);
strict=cfg; strict.aero_extrapolation_policy="error";
state=trim; state.velocity=R*[0;0;1]; rejected=false;
try
    ca_plant_outputs(state,model,strict,0);
catch problem
    rejected=strcmp(problem.identifier,'ca:AeroTableDomain');
end
assert(rejected,'严格模式没有拦截气动表越界。');
report=struct('rhs_max_errors',max(errors,[],1),'P_cs_b',p.P_cs_b, ...
    'B_tau',model.torque_matrix,'B_acc',model.acceleration_matrix,'J_b',p.J_b, ...
    'hinges_b_planar',p.hinges_b(:,1:2),'hinge_axial_status',p.hinge_axial_status, ...
    'hover_motor_rad_s',model.hover_motor_rad_s,'hover_exit_speed_m_s',model.hover_exit_speed_m_s, ...
    'trim_delta_deg',rad2deg(model.trim_delta_rad));
outdir=fullfile(folder,'results','validation'); if ~isfolder(outdir), mkdir(outdir); end
save(fullfile(outdir,'shc09_physics.mat'),'report');
fprintf('b 系 40 状态、PX4/SDF 独立 B、配平、严格域检查全部通过。\n');
disp(report);
end
