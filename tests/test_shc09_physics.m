function report = test_shc09_physics()
% 用参考工程原函数独立核对物理方程、配平和积分精度。
folder=ca_setup();
cfg=ca_validate_config(ca_config());
model=ca_model(cfg); p=model.parameters;
reference=fullfile(folder,'models','shc09','reference');
addpath(reference);
cleanup=onCleanup(@()rmpath(reference));
d=load(fullfile(reference,'duct_raw.mat')); w=load(fullfile(reference,'wing_raw.mat'));
source=Initialized_SHC09(d.duct_raw,w.wing_raw,p.g,pi/180);
assert(norm(source.P_cs-p.P_cs,'fro')==0 && norm(source.J-p.J,'fro')==0,'参考模型参数不一致。');
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
    x=[state.position;state.velocity;angles;state.omega];
    [dx,force,source_state]=SHC09_Sys(0,x,source,Env,Actuator,Dist,struct(),struct());
    out=ca_plant_outputs(state,model,trial,0);
    errors(k,:)=[norm(dx(4:6)-out.acceleration_ned_m_s2,Inf), ...
        norm(dx(10:12)-out.alpha_rad_s2,Inf),abs(source_state.Ve-out.exit_speed_m_s)];
    sensor_force=out.force_body_n+state.rotation'*trial.external_force_ned_n;
    assert(norm(sensor_force-[force.Fx;force.Fy;force.Fz],Inf)<1e-11,'非重力比力不一致。');
end
assert(max(errors,[],'all')<1e-10,'新物理方程与参考工程不一致。');
trim=ca_plant_init(model); out=ca_plant_outputs(trim,model,cfg,0);
assert(norm(out.alpha_rad_s2)<1e-10 && norm(out.acceleration_ned_m_s2)<1e-10,'悬停配平失败。');
sensor=ca_sensor_init(cfg,trim.delta);
[measurement,~]=ca_sensor_step(zeros(3,1),trim.delta,zeros(3,1),sensor,cfg);
assert(norm(measurement.delta_feedback-trim.delta)<1e-12,'配平滤波器产生了启动冲击。');
% 比较多步物理积分与参考工程高精度积分，固定执行器以隔离数值误差。
initial=trim; initial.velocity=[1.3;2.2;0.5]; initial.omega=[0.1;-0.2;0.15];
initial.rotation=ca_euler_rotation([0.1;-0.08;0.04]);
x=[initial.position;initial.velocity;ca_rotation_euler(initial.rotation);initial.omega];
Dist=struct('Dx',0,'Dy',0,'Dz',0,'Fx',0,'Fy',0,'Fz',0,'Mx',0,'My',0,'Mz',0);
Actuator=struct('u',initial.delta,'omega_m',initial.motor);
[~,trajectory]=ode45(@(t,x)SHC09_Sys(t,x,source,Env,Actuator,Dist,struct(),struct()), ...
    [0,0.02],x,odeset('RelTol',1e-11,'AbsTol',1e-12));
truth=trajectory(end,:)'; integration_errors=zeros(1,2);
for rate=1:2
    state=initial; dt=1/(cfg.sample_hz*rate);
    for k=1:round(0.02/dt)
        state=ca_plant_step(state,initial.delta,initial.motor,dt,model,cfg,(k-1)*dt);
    end
    estimate=[state.position;state.velocity;ca_rotation_euler(state.rotation);state.omega];
    integration_errors(rate)=norm(estimate-truth,Inf);
end
assert(integration_errors(1)<1e-4 && integration_errors(2)<0.4*integration_errors(1),'中点积分精度或收敛阶异常。');
% 固定名义矩阵与真实随气流变化的矩阵分离，避免分配器获知真实气流。
state=trim; state.velocity=[2;3;1]; moving=ca_plant_outputs(state,model,cfg,0);
assert(norm(moving.actual_torque_matrix-model.torque_matrix,'fro')>0.01,'真实气流未改变舵效。');
assert(isequal(model.acceleration_matrix,model.inertia\model.torque_matrix),'名义分配矩阵意外改变。');
% 纯下沉的涵道迎角为一百八十度，严格模式必须拒绝外推。
strict=cfg; strict.aero_extrapolation_policy="error";
state=trim; state.velocity=[0;0;1]; rejected=false;
try
    ca_plant_outputs(state,model,strict,0);
catch problem
    rejected=strcmp(problem.identifier,'ca:AeroTableDomain');
end
assert(rejected,'严格模式没有拦截气动表越界。');
report=struct('rhs_max_errors',max(errors,[],1),'integration_errors',integration_errors, ...
    'hover_motor_rad_s',model.hover_motor_rad_s,'hover_exit_speed_m_s',model.hover_exit_speed_m_s, ...
    'trim_delta_deg',rad2deg(model.trim_delta_rad),'nominal_torque_matrix',model.torque_matrix);
outdir=fullfile(folder,'results','validation'); if ~isfolder(outdir), mkdir(outdir); end
save(fullfile(outdir,'shc09_physics.mat'),'report');
fprintf('参考工程40个状态方程核对、静止配平、滤波初始化与积分收敛全部通过。\n');
disp(report);
end
