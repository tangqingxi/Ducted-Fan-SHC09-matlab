function report = test_estimator_isolation()
% 非零测量偏置下必须与真值不同；控制器姿态必须严格来自估计topic。
c=ca_config();c.estimator_mode="lite";c.duration_s=0.2;c.aero_low_speed_model="hold_90";c.aero_extrapolation_policy="error";
c=ca_validate_config(c);m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);L=ca_simulate(m,c,r,"WLS",e);
assert(all(L.estimator_health) && max(L.estimated_attitude_error_rad)>1e-4);
assert(~isfield(L.topic_log,'plant_truth') && ~isfield(L.topic_log,'sensor_attitude') && ~isfield(L.topic_log,'sensor_local_position'));
h=L.topic_log.vehicle_attitude;rows=find(h.time_s>=0);assert(numel(rows)==numel(r.time_s));
for k=1:numel(rows),assert(norm(ca_euler_rotation(L.measured_euler_rad(k,:)')-h.data{rows(k)}.rotation,'fro')<1e-12);end
% 健康错误必须显式失败；不注入替代真值。
bus=Shc09Bus();bus.publish('sensor_imu',struct('gyro',[NaN;0;0],'accel',[0;0;-9.788]),0);
bus.publish('sensor_baro',struct('fresh',false),0);bus.publish('sensor_mag',struct('fresh',false),0);bus.publish('sensor_gnss',struct('fresh',false),0);
shc09_estimator_lite_module(bus,[],shc09_lite_params(c),0);h=bus.latest('estimator_health');assert(~h.valid && ~bus.exists('vehicle_attitude'));
report=struct('no_truth_topics',true,'control_uses_estimate',true,'invalid_imu_rejected',true);
end
