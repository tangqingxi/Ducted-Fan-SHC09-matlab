function state = ca_plant_step(state,held,motor_command,duration_s,model,cfg,time_s)
% 分段显式中点积分；时变舵机参数在各子段中点冻结，常参数时仍为精确一阶响应。
rate=deg2rad(cfg.rate_limit_deg_s);
first=ca_plant_outputs(state,model,cfg,time_s);
mid=state;
mid.delta=ca_actuator_step(state.delta,held,ca_true_actuator_tau(time_s+duration_s/4,cfg),duration_s/2,rate);
mid.motor=ca_motor_step(state.motor,motor_command,cfg.motor_tau_s,duration_s/2,model);
mid.omega=state.omega+duration_s/2*first.alpha_rad_s2;
mid.rotation=state.rotation*ca_rotation_increment(duration_s/2*state.omega);
mid.position=state.position+duration_s/2*state.velocity;
mid.velocity=state.velocity+duration_s/2*first.acceleration_ned_m_s2;
second=ca_plant_outputs(mid,model,cfg,time_s+duration_s/2);
state.rotation=state.rotation*ca_rotation_increment((state.omega+duration_s/2*second.alpha_rad_s2)*duration_s);
state.omega=state.omega+duration_s*second.alpha_rad_s2;
state.position=state.position+duration_s*mid.velocity;
state.velocity=state.velocity+duration_s*second.acceleration_ned_m_s2;
state.delta=ca_actuator_step(state.delta,held,ca_true_actuator_tau(time_s+duration_s/2,cfg),duration_s,rate);
state.motor=ca_motor_step(state.motor,motor_command,cfg.motor_tau_s,duration_s,model);
end
