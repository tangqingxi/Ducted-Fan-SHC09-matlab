function shc09_attitude_module(bus,cfg,time_s)
% 姿态环只读取估计姿态、测量角速度和姿态参考。
attitude=bus.subscribe('vehicle_attitude');rate=bus.subscribe('vehicle_angular_velocity');reference=bus.subscribe('vehicle_attitude_setpoint');
[omega,alpha]=ca_attitude_control(attitude.rotation,rate.omega,reference.rotation,reference.omega,reference.alpha,cfg);
bus.publish('vehicle_rates_setpoint',struct('omega',omega,'alpha',alpha),time_s);
end
