function shc09_position_module(bus,model,cfg,time_s)
% 外环订阅估计位置及轨迹；只有显式启用F8时消费平移和几何姿态前馈。
position=bus.subscribe('vehicle_local_position');reference=bus.subscribe('trajectory_setpoint');
if isfield(cfg,'f8_feedforward_enabled')&&cfg.f8_feedforward_enabled
    [rotation,motor,omega,alpha]=ca_f8_position_control(position.position,position.velocity,reference,model,cfg);
else
    [rotation,motor]=ca_position_control(position.position,position.velocity,reference.yaw,model,cfg,reference.position);
    omega=zeros(3,1);alpha=zeros(3,1);
end
bus.publish('vehicle_attitude_setpoint',struct('rotation',rotation,'omega',omega,'alpha',alpha),time_s);
bus.publish('vehicle_thrust_setpoint',struct('motor_command',motor),time_s);
end
