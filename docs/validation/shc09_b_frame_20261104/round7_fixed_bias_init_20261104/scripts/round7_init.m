function [nav,bus,fusion,I]=round7_init(cfg,model,plan,noise)
% 仅通过静置模拟测量对准EKF；不把真实状态作为滤波器初值或控制反馈。
nav=struct('bridge',CaPx4Ecl(cfg),'noise',noise,'index',0);
% 传感器包要求 body->FRD；新 b 系下 b=C*FRD，故 FRD=C'*b。
nav.body_to_frd=model.parameters.C_old_to_frd*model.parameters.R_old_to_b';
nav.earth_rate_ned_rad_s=7.292115e-5*[cosd(cfg.navigation_origin(1));0;-sind(cfg.navigation_origin(1))];
nav.gravity_m_s2=model.parameters.g;
nav.delay_samples=round(cfg.sample_hz*[cfg.gnss_delay_s,cfg.barometer_delay_s,cfg.magnetometer_delay_s]);
nav.sample_strides=round(cfg.sample_hz./[cfg.gnss_hz,cfg.barometer_hz,cfg.magnetometer_hz]);
nav.buffer_length=max(nav.delay_samples)+1;
nav.gps_position_buffer=zeros(nav.buffer_length,3);nav.gps_velocity_buffer=zeros(nav.buffer_length,3);
nav.baro_buffer=zeros(nav.buffer_length,1);nav.mag_buffer=zeros(nav.buffer_length,3);
runtime=shc09_runtime(cfg);bus=runtime.bus;
fusion=struct('bridge',nav.bridge,'body_to_frd',nav.body_to_frd,'earth_rate_ned_rad_s',nav.earth_rate_ned_rad_s);
stationary=ca_plant_init(model,cfg);physical=struct('acceleration_ned_m_s2',zeros(3,1));
% 只增加静置对准的只读诊断记录，原传感器和融合调用次序保持不变。
I.time_s=((1:noise.warmup_samples)'-noise.warmup_samples)/cfg.sample_hz;
I.raw=zeros(noise.warmup_samples,3);I.velocity=I.raw;I.truth=I.raw;
I.gnss=nan(noise.warmup_samples,3);I.fresh=false(noise.warmup_samples,1);
I.valid=I.fresh;I.gps_active=I.fresh;I.packet_time_us=zeros(noise.warmup_samples,1);
for k=1:noise.warmup_samples
    [packet,observation,nav]=ppid_sensor_step(stationary,physical,nav,cfg,false,plan);
    bus.publish('sensor_navigation',struct('packet',packet,'observation',observation),(k-noise.warmup_samples)/cfg.sample_hz);
    nav.estimate=shc09_navigation_module(bus,fusion,(k-noise.warmup_samples)/cfg.sample_hz);
    I.raw(k,:)=nav.estimate.position';I.velocity(k,:)=nav.estimate.velocity';I.truth(k,:)=stationary.position';
    I.fresh(k)=observation.fresh(1);I.packet_time_us(k)=packet(1);
    if I.fresh(k),I.gnss(k,:)=observation.gps_position;end
    I.valid(k)=nav.estimate.position_valid;I.gps_active(k)=nav.estimate.gps_active;
end
e=nav.estimate;
assert(e.attitude_valid&&e.position_valid&&e.yaw_aligned&&e.origin_valid&&e.fault_code==0, ...
    'ppid:NotAligned','测量驱动的ECL对准失败，不使用真值替代。');
end
