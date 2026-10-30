function estimate = shc09_navigation_fuse(packet,observation,nav)
% 融合只接收传感器包及固定坐标参数，保持原解码与地转校正次序。
Q=nav.body_to_frd;gyro=observation.gyro;specific_force=observation.specific_force;
fresh=observation.fresh;gps_position=observation.gps_position;
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
end
