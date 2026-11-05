function delta_hat = shc09_actuator_estimator_module(bus,delta_hat,held,duration_s,cfg,time_s)
% 名义舵角估计只积分已经生效的保持命令。
delta_hat=ca_state_estimator_step(delta_hat,held,duration_s,cfg);
bus.publish('estimated_actuator_state',struct('delta_hat',delta_hat),time_s);
end
