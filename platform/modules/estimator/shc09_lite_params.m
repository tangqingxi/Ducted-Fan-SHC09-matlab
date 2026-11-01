function p = shc09_lite_params(cfg)
% 只提取估计器增益和公开常量，不传真实偏置/物理状态。
names=["sample_hz","lite_attitude_kp","lite_attitude_ki","lite_gravity_m_s2", ...
 "lite_magnetic_ned_gauss","lite_position_tau_s","lite_velocity_tau_s","lite_baro_tau_s", ...
 "lite_gnss_timeout_s","lite_max_innovation_rad","navigation_origin","lite_gnss_correction_tau_s", ...
 "lite_velocity_aiding_enabled","lite_velocity_aiding_gain_s2","lite_velocity_aiding_tau_s", ...
 "lite_velocity_aiding_max_rate_deg_s","lite_velocity_aiding_history_s","lite_velocity_aiding_hold_s"];
p=struct();for name=names,p.(name)=cfg.(name);end
assert(isscalar(p.lite_gnss_correction_tau_s)&&isfinite(p.lite_gnss_correction_tau_s)&&p.lite_gnss_correction_tau_s>0,'lite的GNSS修正注入时间常数必须为正有限数。');
assert(isscalar(p.lite_velocity_aiding_enabled)&&ismember(p.lite_velocity_aiding_enabled,[0,1]),'GNSS速度辅助开关必须为逻辑标量。');
for name=["lite_velocity_aiding_gain_s2","lite_velocity_aiding_tau_s","lite_velocity_aiding_max_rate_deg_s", ...
    "lite_velocity_aiding_history_s","lite_velocity_aiding_hold_s"]
    assert(isscalar(p.(name))&&isfinite(p.(name))&&p.(name)>0,'速度辅助参数必须为正有限数。');
end
% 诊断门控不进入默认配置，只传公开测量阈值。
if isfield(cfg,'diagnosis_accel_gate_enabled')
 p.diagnosis_accel_gate_enabled=cfg.diagnosis_accel_gate_enabled;
 p.diagnosis_accel_gate_m_s2=cfg.diagnosis_accel_gate_m_s2;
 p.diagnosis_rate_gate_rad_s=cfg.diagnosis_rate_gate_rad_s;
end
end
