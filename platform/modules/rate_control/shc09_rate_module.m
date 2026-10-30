function shc09_rate_module(bus,model,cfg,time_s)
% 角速度环只用测量、历史舵角、参考和名义矩阵，发布需求分解适配器。
rate=bus.subscribe('vehicle_angular_velocity');alpha=bus.subscribe('vehicle_angular_acceleration');
actuator=bus.subscribe('filtered_actuator_state');reference=bus.subscribe('vehicle_rates_setpoint');
[v_h,v_c]=ca_indi_rate_control(rate.omega,alpha.alpha,actuator.delta_feedback,reference.omega,reference.alpha,model,cfg);
bus.publish('vehicle_torque_setpoint',struct('v_h',v_h,'v_c',v_c),time_s);
end
