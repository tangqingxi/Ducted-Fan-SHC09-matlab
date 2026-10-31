function p = shc09_lite_params(cfg)
% 只提取估计器增益和公开常量，不传真实偏置/物理状态。
names=["sample_hz","lite_attitude_kp","lite_attitude_ki","lite_gravity_m_s2", ...
 "lite_magnetic_ned_gauss","lite_position_tau_s","lite_velocity_tau_s","lite_baro_tau_s", ...
 "lite_gnss_timeout_s","lite_max_innovation_rad","navigation_origin"];
p=struct();for name=names,p.(name)=cfg.(name);end
end
