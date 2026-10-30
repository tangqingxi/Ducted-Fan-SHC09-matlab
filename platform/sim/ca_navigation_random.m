function noise = ca_navigation_random(cfg,gyro_noise)
% 预生成独立传感器随机流；各分配方法接收同一组噪声样本和偏置参数。
n=size(gyro_noise,1); warm=round(cfg.navigation_warmup_s*cfg.sample_hz); total=n+warm;
seed=cfg.navigation_seed;
enabled=double(cfg.feedback_noise_enabled);
stream=RandStream('mt19937ar','Seed',seed);
noise.gyro_rad_s=[enabled*deg2rad(cfg.gyro_noise_std_deg_s)*randn(stream,warm,3);gyro_noise];
stream=RandStream('mt19937ar','Seed',seed+1);
noise.accelerometer_m_s2=enabled*cfg.accelerometer_noise_std_m_s2*randn(stream,total,3);
stream=RandStream('mt19937ar','Seed',seed+2);
noise.gnss_position_m=enabled*randn(stream,total,3).*cfg.gnss_position_std_m(:)';
stream=RandStream('mt19937ar','Seed',seed+3);
noise.gnss_velocity_m_s=enabled*cfg.gnss_velocity_std_m_s*randn(stream,total,3);
stream=RandStream('mt19937ar','Seed',seed+4);
noise.barometer_m=enabled*cfg.barometer_noise_std_m*randn(stream,total,1);
stream=RandStream('mt19937ar','Seed',seed+5);
noise.magnetometer_gauss=enabled*cfg.magnetometer_noise_std_gauss*randn(stream,total,3);
noise.warmup_samples=warm;
end
