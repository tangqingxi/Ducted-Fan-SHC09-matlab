function [experiment,comp]=round5_components(cfg,ref,plan)
% 复现 ppid_noise 的 GNSS slow+white 分解，并保留两分量供 A/B/C 复用。
experiment=ca_prepare_experiment(cfg,ref.time_s);noise=experiment.navigation;
n=size(noise.gyro_rad_s,1);dt=1/cfg.sample_hz;
stream=RandStream('mt19937ar','Seed',cfg.navigation_seed+20);
noise.gyro_walk=deg2rad(plan.sensors.gyro_bias_walk_deg_s_sqrt_s)*sqrt(dt)*cumsum(randn(stream,n,3),1);
noise.accel_walk=plan.sensors.accel_bias_walk_m_s2_sqrt_s*sqrt(dt)*cumsum(randn(stream,n,3),1);
noise.gyro_rad_s=noise.gyro_rad_s+noise.gyro_walk;
noise.accelerometer_m_s2=noise.accelerometer_m_s2+noise.accel_walk;
stream=RandStream('mt19937ar','Seed',cfg.navigation_seed+21);
phi=exp(-dt/plan.sensors.gnss_correlation_s);
white=plan.sensors.gnss_white_axis_sigma_m(:)';
slow=sqrt(cfg.gnss_position_std_m(:)'.^2-white.^2);
values=zeros(n,3);values(1,:)=randn(stream,1,3);
for k=2:n,values(k,:)=phi*values(k-1,:)+sqrt(1-phi^2)*randn(stream,1,3);end
comp.slow_m=values.*slow;
comp.white_m=randn(stream,n,3).*white;
comp.total_m=comp.slow_m+comp.white_m;
comp.white_sigma=white;comp.slow_sigma=slow;comp.phi=phi;comp.warmup_samples=noise.warmup_samples;
noise.gnss_position_m=comp.total_m;
experiment.navigation=noise;
end
