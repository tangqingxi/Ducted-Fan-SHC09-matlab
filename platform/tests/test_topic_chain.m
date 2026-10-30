function test_topic_chain()
% 模块只能读取公开测量/估计topic；验证最小指令与控制数据流。
cfg=ca_config();model=ca_model(cfg);bus=Shc09Bus();
bus.publish('sensor_attitude',struct('rotation',eye(3)),0);
bus.publish('sensor_local_position',struct('position',[0;0;-10],'velocity',zeros(3,1)),0);
shc09_estimator_module(bus,0);
bus.publish('trajectory_setpoint',struct('position',[0;0;-10],'yaw',0),0);
shc09_position_module(bus,model,shc09_module_params(cfg,"position"),0);
bus.publish('vehicle_angular_velocity',struct('omega',zeros(3,1)),0);
shc09_attitude_module(bus,shc09_module_params(cfg,"attitude"),0);
bus.publish('vehicle_angular_acceleration',struct('alpha',zeros(3,1)),0);
bus.publish('filtered_actuator_state',struct('delta_feedback',model.trim_delta_rad),0);
shc09_rate_module(bus,struct('acceleration_matrix',model.acceleration_matrix),shc09_module_params(cfg,"rate"),0);
assert(bus.exists('vehicle_torque_setpoint') && ~bus.exists('plant_truth'));
s=shc09_commander_module(bus,struct('mode',"position_hold"),0);assert(s.armed);
s=shc09_commander_module(bus,struct('failsafe',true),0);assert(~s.armed && s.failsafe);
end
