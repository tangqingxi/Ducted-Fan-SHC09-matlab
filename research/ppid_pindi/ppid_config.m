function [cfg,model,ref,plan]=ppid_config(seed)
% 复用原轨迹几何与物理对象，只在新研究配置中改变公共控制及测量链。
root=ca_setup();plan=jsondecode(fileread(fullfile(root,'research','ppid_pindi','protocol.json')));
[cfg,model,ref]=ca_f8_pressure_protocol('F8PR-Y60-F075',201,2);
cfg.estimator_mode="px4_ecl";cfg.navigation_mode="px4_ecl";
cfg.navigation_warmup_s=plan.sensors.warmup_s;cfg.sample_hz=800;
cfg.navigation_seed=seed;cfg.gyro_noise_seed=seed+100;cfg.disturbance_seed=seed+200;
cfg.gyro_noise_std_deg_s=plan.sensors.gyro_noise_density_deg_s_sqrtHz*sqrt(cfg.sample_hz/2);
cfg.accelerometer_noise_std_m_s2=plan.sensors.accel_noise_density_m_s2_sqrtHz*sqrt(cfg.sample_hz/2);
cfg.gyro_bias_deg_s=plan.sensors.gyro_bias_deg_s(:);
cfg.accelerometer_bias_m_s2=plan.sensors.accel_bias_m_s2(:);
cfg.gnss_position_std_m=plan.sensors.gnss_total_axis_sigma_m(:);
cfg.gnss_position_bias_m=zeros(3,1);cfg.gnss_velocity_std_m_s=plan.sensors.gnss_velocity_sigma_m_s;
cfg.gnss_hz=5;cfg.gnss_delay_s=0.1;
cfg.barometer_noise_std_m=0.25;cfg.barometer_bias_m=0.4;cfg.barometer_hz=50;cfg.barometer_delay_s=0.03;
cfg.magnetometer_noise_std_gauss=0.003;cfg.magnetometer_bias_gauss=[0.001;-0.001;0.002];
cfg.magnetometer_hz=50;cfg.magnetometer_delay_s=0.01;
cfg=ca_validate_config(cfg);
assert(cfg.sample_hz==800&&cfg.pwm_hz==333&&numel(ref.time_s)==41601);
assert(isequal(cfg.tau_actual_s,0.001*[24;27;30;33;36;40]));
assert(isequaln(ca_model(cfg),model),'名义模型受到私有真实参数影响。');
% 返回给驱动、实验和保存 .mat 的参考必须是 b 系，不能只让 ppid_simulate 内部转换。
ref=ca_reference_to_b(ref,model);
end
