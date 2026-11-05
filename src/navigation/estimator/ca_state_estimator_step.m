function delta_hat = ca_state_estimator_step(delta_hat,held,duration_s,cfg)
% 舵角估计只积分已下发指令，不读取实际舵角、时间常数或气流。
delta_hat=ca_actuator_step(delta_hat,held,cfg.tau_model_s,duration_s,deg2rad(cfg.rate_limit_deg_s));
end
