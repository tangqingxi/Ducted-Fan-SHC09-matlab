function shc09_allocator_module(bus,name,nominal,cfg,timing,time_s)
% 组合名义效能与插件，状态保留任意info，不解释算法专属分支。
demand=bus.subscribe('vehicle_torque_setpoint');state=bus.subscribe('estimated_actuator_state');
[command,info]=ca_allocate(name,demand.v_h,demand.v_c,state.delta_hat,nominal,cfg,timing);
thrust=bus.subscribe('vehicle_thrust_setpoint');
bus.publish('actuator_servos',struct('command',command,'source_time_s',time_s),time_s);
bus.publish('actuator_motors',thrust,time_s);
bus.publish('control_allocator_status',struct('allocator',string(name),'info',info),time_s);
end
