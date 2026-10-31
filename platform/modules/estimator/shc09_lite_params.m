function p = shc09_lite_params(cfg)
% 只提取估计器增益和公开常量，不传真实偏置/物理状态。
names=["sample_hz","lite_attitude_kp","lite_attitude_ki","lite_gravity_m_s2", ...
 "lite_magnetic_ned_gauss","lite_position_tau_s","lite_velocity_tau_s","lite_baro_tau_s", ...
 "lite_gnss_timeout_s","lite_max_innovation_rad","navigation_origin"];
p=struct();for name=names,p.(name)=cfg.(name);end
% 诊断门控不进入默认配置，只传公开测量阈值。
if isfield(cfg,'diagnosis_accel_gate_enabled')
 p.diagnosis_accel_gate_enabled=cfg.diagnosis_accel_gate_enabled;
 p.diagnosis_accel_gate_m_s2=cfg.diagnosis_accel_gate_m_s2;
 p.diagnosis_rate_gate_rad_s=cfg.diagnosis_rate_gate_rad_s;
end
end
