function tau = ca_true_actuator_tau(time_s,cfg)
% 仅物理对象和日志调用真实参数；控制分配和舵角估计器不得调用此函数。
tau=cfg.tau_actual_s(:);
if isfield(cfg,'actuator_tau_variation_enabled') && cfg.actuator_tau_variation_enabled
    tau=tau.*(1+cfg.actuator_tau_variation_fraction ...
        *sin(2*pi*time_s./cfg.actuator_tau_variation_period_s(:)+cfg.actuator_tau_variation_phase_rad(:)));
end
end
