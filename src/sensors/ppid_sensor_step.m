function [packet,observation,nav]=ppid_sensor_step(state,physical,nav,cfg,in_air,plan)
% 唯一接收对象状态的传感器生成器；输出仅为含误差、滤波和延迟的测量。
[packet,observation,nav]=shc09_navigation_sensors(state,physical,nav,cfg,in_air);
if ~isfield(nav,'imu_filter')
    nav.imu_filter=ca_biquad('lowpass',plan.sensors.imu_lowpass_hz,cfg.sample_hz,6);
    initial=[observation.gyro;observation.specific_force];
    nav.imu_filter.state=[(1-nav.imu_filter.b(1))*initial'; ...
        (nav.imu_filter.b(3)-nav.imu_filter.a(3))*initial'];
    length=1+round(plan.sensors.imu_transport_delay_s*cfg.sample_hz);
    nav.imu_buffer=repmat(initial,1,length);
end
[value,nav.imu_filter]=ca_biquad_step([observation.gyro;observation.specific_force],nav.imu_filter);
slot=mod(nav.index-1,size(nav.imu_buffer,2))+1;nav.imu_buffer(:,slot)=value;
old=mod(nav.index-size(nav.imu_buffer,2),size(nav.imu_buffer,2))+1;
value=nav.imu_buffer(:,old);
observation.gyro=value(1:3);observation.specific_force=value(4:6);
packet(4:6)=(nav.body_to_frd*observation.gyro)';
packet(7:9)=(nav.body_to_frd*observation.specific_force)';
end
