function [estimate,nav] = ca_navigation_step(state,physical,nav,cfg,in_air)
% 真值仅在此生成带误差的原始传感器，不用于直接设置滤波器状态或控制反馈。
nav.index=nav.index+1; k=nav.index; dt=1/cfg.sample_hz; Q=nav.body_to_frd;
gyro=state.omega+state.rotation'*nav.earth_rate_ned_rad_s+deg2rad(cfg.gyro_bias_deg_s(:))+nav.noise.gyro_rad_s(k,:)';
specific_force=state.rotation'*(physical.acceleration_ned_m_s2-[0;0;nav.gravity_m_s2]) ...
    +cfg.accelerometer_bias_m_s2(:)+nav.noise.accelerometer_m_s2(k,:)';
magnetic=state.rotation'*nav.bridge.magnetic_ned_gauss+cfg.magnetometer_bias_gauss(:)+nav.noise.magnetometer_gauss(k,:)';
slot=mod(k-1,nav.buffer_length)+1;
nav.gps_position_buffer(slot,:)=state.position'+cfg.gnss_position_bias_m(:)'+nav.noise.gnss_position_m(k,:);
nav.gps_velocity_buffer(slot,:)=state.velocity'+nav.noise.gnss_velocity_m_s(k,:);
nav.baro_buffer(slot)=cfg.navigation_origin(3)-state.position(3)+cfg.barometer_bias_m+nav.noise.barometer_m(k);
nav.mag_buffer(slot,:)=(Q*magnetic)';
source=k-nav.delay_samples; slots=mod(source-1,nav.buffer_length)+1;
fresh=source>=1 & mod(source-1,nav.sample_strides)==0;
gps_position=zeros(1,3); gps_velocity=gps_position; baro=0; mag=zeros(1,3);
if fresh(1), gps_position=nav.gps_position_buffer(slots(1),:); gps_velocity=nav.gps_velocity_buffer(slots(1),:); end
if fresh(2), baro=nav.baro_buffer(slots(2)); end
if fresh(3), mag=nav.mag_buffer(slots(3),:); end
packet=[1000000+round(k*dt*1e6),dt,double(in_air),(Q*gyro)',(Q*specific_force)', ...
    fresh(1),gps_position,gps_velocity,fresh(2),baro,fresh(3),mag];
values=nav.bridge.step(packet);
estimate.rotation=ca_quaternion_rotation(values(1:4))*Q;
estimate.position=values(5:7); estimate.velocity=values(8:10);
estimate.gyro_bias=Q'*values(11:13); estimate.accelerometer_bias=Q'*values(14:16);
estimate.position_variance=values(17:19); estimate.attitude_valid=logical(values(20));
estimate.position_valid=logical(values(21)); estimate.yaw_aligned=logical(values(22));
estimate.gps_active=logical(values(23)); estimate.origin_valid=logical(values(24));
estimate.fault_code=values(25); estimate.updated=logical(values(26));
estimate.raw_gyro=gyro; estimate.raw_specific_force=specific_force; estimate.new_aiding=fresh;
estimate.gnss_position=gps_position'; if ~fresh(1), estimate.gnss_position(:)=NaN; end
% 控制侧仅用估计偏置和估计姿态去除已知地转项，不读取真实姿态作校正。
estimate.rate_earth_corrected=gyro-estimate.gyro_bias-estimate.rotation'*nav.earth_rate_ned_rad_s;
nav.estimate=estimate;
end
