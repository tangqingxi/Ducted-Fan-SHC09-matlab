function noise = shc09_lite_random(cfg,n)
% 独立随机流及一阶带限陀螺噪声；不改变旧ideal随机调用。
a=exp(-2*pi*cfg.gyro_lpf_hz/cfg.sample_hz);
sigma=deg2rad(cfg.gyro_noise_density_dps_sqrtHz)*sqrt(pi*cfg.gyro_lpf_hz/2);
s=RandStream('mt19937ar','Seed',cfg.lite_seed);raw=randn(s,n,3);
noise.gyro=zeros(n,3);noise.gyro(1,:)=sigma*raw(1,:);
for k=2:n,noise.gyro(k,:)=a*noise.gyro(k-1,:)+sigma*sqrt(1-a*a)*raw(k,:);end
s=RandStream('mt19937ar','Seed',cfg.lite_seed+1);
noise.walk=cumsum(deg2rad(cfg.gyro_bias_walk_deg_s_sqrt_s)/sqrt(cfg.sample_hz)*randn(s,n,3),1);
fields={'accel','mag','baro','position','velocity'};
scales={cfg.accelerometer_noise_std_m_s2,cfg.magnetometer_noise_std_gauss,cfg.barometer_noise_std_m,cfg.gnss_position_std_m(:)',cfg.gnss_velocity_std_m_s};
for k=1:5
 s=RandStream('mt19937ar','Seed',cfg.lite_seed+1+k);width=3;if k==3,width=1;end
 noise.(fields{k})=randn(s,n,width).*scales{k};
end
if ~cfg.feedback_noise_enabled,for name=reshape(string(fieldnames(noise)),1,[]),noise.(name)(:)=0;end,end
end
