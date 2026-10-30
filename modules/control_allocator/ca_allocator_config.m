function nominal = ca_allocator_config(cfg)
% 显式白名单隔离物理真值、传感器真实偏置和外部扰动，分配器只取得名义模型及求解设置。
allowed=["sample_hz","pwm_hz","pwm_phase_s","tau_model_s","rate_limit_deg_s", ...
    "max_iterations","constraint_tolerance","wls_axis_weights","wls_gamma","wls_input_weight", ...
    "dca_horizon_s","predictive_horizon_fraction","predictive_restore_mode"];
nominal=struct();
for field=allowed
    if isfield(cfg,field), nominal.(field)=cfg.(field); end
end
end
