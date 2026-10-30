function sensor = shc09_sensors_module(bus,sensor,cfg,time_s)
% 订阅模拟测量与模型舵角，发布公共角速度/角加速度和历史滤波舵角。
imu=bus.subscribe('sensor_imu');actuator=bus.subscribe('estimated_actuator_state');
if string(cfg.measurement_mode)=="meng_filtered"
    [measurement,sensor]=ca_sensor_step(imu.rate,actuator.delta_hat,imu.noise,sensor,cfg);
    omega=measurement.omega;alpha=measurement.alpha;delta=measurement.delta_feedback;
else
    omega=imu.rate;alpha=imu.alpha;delta=actuator.delta_hat;
end
bus.publish('vehicle_angular_velocity',struct('omega',omega),time_s);
bus.publish('vehicle_angular_acceleration',struct('alpha',alpha),time_s);
bus.publish('filtered_actuator_state',struct('delta_feedback',delta),time_s);
end
