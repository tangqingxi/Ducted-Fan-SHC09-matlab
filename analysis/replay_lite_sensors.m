function [report,replay] = replay_lite_sensors(mat_path,overrides,estimator_function)
% 用既有轨迹重建原始传感器，真值仅在测量生成和离线误差评价中使用。
% 估计函数的入口仍只有总线、内部状态、公开参数及时间，不接收物理状态。
ca_setup();if nargin<2,overrides=struct();end
if nargin<3,estimator_function=@shc09_estimator_lite_module;end
d=load(mat_path,'L','c','ref','model');L=d.L;c=d.c;
for name=reshape(string(fieldnames(overrides)),1,[]),c.(name)=overrides.(name);end
c=ca_validate_config(c);p=shc09_lite_params(c);n=numel(d.ref.time_s);warm=round(c.navigation_warmup_s*c.sample_hz);
noise=shc09_lite_random(c,warm+n);bus=Shc09Bus();s=[];memory=[];initial=ca_plant_init(d.model,c);
physical=struct('acceleration_ned_m_s2',zeros(3,1));
for k=1:warm
    [q,memory]=shc09_lite_sensors(initial,physical,c,noise,k,memory);
    t=(k-warm-1)/c.sample_hz;shc09_lite_publish(bus,q,t);s=estimator_function(bus,s,p,t);
end
replay=struct('time_s',d.ref.time_s,'euler_rad',zeros(n,3),'position_ned_m',zeros(n,3),'velocity_ned_m_s',zeros(n,3), ...
    'bias_rad_s',zeros(n,3),'attitude_error_deg',zeros(n,1),'legacy_rotation_difference',zeros(n,1), ...
    'legacy_position_difference_m',zeros(n,1),'legacy_velocity_difference_m_s',zeros(n,1));
for i=1:n
    % 位置、速度、姿态只进入传感器模拟器；IMU直接使用原日志的同一原始测量。
    x=initial;x.position=L.position_ned_m(i,:)';x.velocity=L.velocity_ned_m_s(i,:)';
    x.rotation=ca_euler_rotation(L.euler_rad(i,:)');x.omega=L.omega_rad_s(i,:)';
    [q,memory]=shc09_lite_sensors(x,physical,c,noise,warm+i,memory);
    q.imu.gyro=L.raw_gyro_rad_s(i,:)';q.imu.accel=L.raw_specific_force_m_s2(i,:)';
    shc09_lite_publish(bus,q,d.ref.time_s(i));s=estimator_function(bus,s,p,d.ref.time_s(i));
    health=bus.latest('estimator_health');assert(health.valid,'shc09:LiteReplayHealth','传感器回放估计无效。');
    replay.euler_rad(i,:)=ca_rotation_euler(s.rotation)';replay.position_ned_m(i,:)=s.position';
    replay.velocity_ned_m_s(i,:)=s.velocity';replay.bias_rad_s(i,:)=s.bias';
    replay.attitude_error_deg(i)=rad2deg(acos(min(1,max(-1,(trace(x.rotation'*s.rotation)-1)/2))));
    replay.legacy_rotation_difference(i)=norm(ca_euler_rotation(L.measured_euler_rad(i,:)')-s.rotation,'fro');
    replay.legacy_position_difference_m(i)=norm(s.position-L.estimated_position_ned_m(i,:)');
    replay.legacy_velocity_difference_m_s(i)=norm(s.velocity-L.estimated_velocity_ned_m_s(i,:)');
end
assert(~bus.exists('plant_truth')&&~bus.exists('sensor_attitude')&&~bus.exists('sensor_local_position'));
chosen=d.ref.time_s>=6&d.ref.time_s<=min(50,d.ref.time_s(end));
position=replay.position_ned_m-L.position_ned_m;velocity=replay.velocity_ned_m_s-L.velocity_ned_m_s;
report=struct('source',string(mat_path),'estimator',string(func2str(estimator_function)), ...
    'attitude_rmse_deg',sqrt(mean(replay.attitude_error_deg(chosen).^2)), ...
    'attitude_peak_deg',max(replay.attitude_error_deg(chosen)), ...
    'position_estimate_rmse_m',sqrt(mean(sum(position(chosen,:).^2,2))), ...
    'velocity_estimate_rmse_m_s',sqrt(mean(sum(velocity(chosen,:).^2,2))), ...
    'max_legacy_rotation_difference',max(replay.legacy_rotation_difference), ...
    'max_legacy_position_difference_m',max(replay.legacy_position_difference_m), ...
    'max_legacy_velocity_difference_m_s',max(replay.legacy_velocity_difference_m_s),'truth_topics_absent',true, ...
    'sensor_replay_only',true,'closed_loop_rerun',false);
disp(report);
end
