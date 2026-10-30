function nav = ca_navigation_init(cfg,model,initial_state,noise)
% 先用静止传感器流完成真实滤波器对准，估计无效时终止而不是回退到真值。
nav=struct(); nav.bridge=CaPx4Ecl(cfg); nav.noise=noise; nav.index=0;
nav.body_to_frd=[0,1,0;-1,0,0;0,0,1];
nav.earth_rate_ned_rad_s=7.292115e-5*[cosd(cfg.navigation_origin(1));0;-sind(cfg.navigation_origin(1))];
nav.gravity_m_s2=model.parameters.g;
nav.delay_samples=round(cfg.sample_hz*[cfg.gnss_delay_s,cfg.barometer_delay_s,cfg.magnetometer_delay_s]);
nav.sample_strides=round(cfg.sample_hz./[cfg.gnss_hz,cfg.barometer_hz,cfg.magnetometer_hz]);
nav.buffer_length=max(nav.delay_samples)+1;
nav.gps_position_buffer=zeros(nav.buffer_length,3); nav.gps_velocity_buffer=zeros(nav.buffer_length,3);
nav.baro_buffer=zeros(nav.buffer_length,1); nav.mag_buffer=zeros(nav.buffer_length,3);
% 静止对准段固定物理初态，相当于起飞前静置，不计入任务时间和性能统计。
stationary=initial_state; stationary.velocity=zeros(3,1); stationary.omega=zeros(3,1);
physical=struct('acceleration_ned_m_s2',zeros(3,1));
try
    for k=1:noise.warmup_samples
        [estimate,nav]=ca_navigation_step(stationary,physical,nav,cfg,false);
    end
    assert(estimate.attitude_valid && estimate.position_valid && estimate.yaw_aligned ...
        && estimate.gps_active && estimate.origin_valid && estimate.fault_code==0, ...
        'ca:NavigationNotAligned','官方EKF未完成对准或GNSS融合，不能使用真值代替。');
catch problem
    nav.bridge.close(); rethrow(problem);
end
nav.warmup_estimate=estimate;
end
