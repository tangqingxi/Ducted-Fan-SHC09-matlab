function experiment=ppid_noise(cfg,ref,plan)
% 仿真器私有随机流；同种子五方法共享误差过程，不向控制器传随机种子和真实偏置。
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
noise.gnss_position_m=values.*slow+randn(stream,n,3).*white;
experiment.navigation=noise;
end
