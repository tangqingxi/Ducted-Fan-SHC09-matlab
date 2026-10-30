function shc09_position_module(bus,model,cfg,time_s)
% 外环订阅估计位置及轨迹，沿用既有控制函数和零角速度前馈。
position=bus.subscribe('vehicle_local_position');reference=bus.subscribe('trajectory_setpoint');
[rotation,motor]=ca_position_control(position.position,position.velocity,reference.yaw,model,cfg,reference.position);
bus.publish('vehicle_attitude_setpoint',struct('rotation',rotation,'omega',zeros(3,1),'alpha',zeros(3,1)),time_s);
bus.publish('vehicle_thrust_setpoint',struct('motor_command',motor),time_s);
end
