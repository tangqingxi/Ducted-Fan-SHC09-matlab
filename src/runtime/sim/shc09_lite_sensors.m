function [messages,memory] = shc09_lite_sensors(state,physical,cfg,noise,k,memory)
% 真值仅用于模拟器生成测量；延迟缓存只保存传感器值。
if isempty(memory)
 memory.length=1+round(cfg.sample_hz*max([cfg.gnss_delay_s,cfg.barometer_delay_s,cfg.magnetometer_delay_s]));
 memory.position=zeros(memory.length,3);memory.velocity=memory.position;memory.mag=memory.position;memory.baro=zeros(memory.length,1);
end
slot=mod(k-1,memory.length)+1;R=state.rotation;
earth=7.292115e-5*[cosd(cfg.navigation_origin(1));0;-sind(cfg.navigation_origin(1))];
messages.imu=struct('gyro',state.omega+R'*earth+deg2rad(cfg.gyro_bias_deg_s(:))+noise.walk(k,:)'+noise.gyro(k,:)', ...
 'sample_time_s',(k-1)/cfg.sample_hz,'accel',R'*(physical.acceleration_ned_m_s2-[0;0;cfg.lite_gravity_m_s2])+cfg.accelerometer_bias_m_s2(:)+noise.accel(k,:)');
memory.position(slot,:)=state.position'+cfg.gnss_position_bias_m(:)'+noise.position(k,:);
memory.velocity(slot,:)=state.velocity'+noise.velocity(k,:);
memory.mag(slot,:)=(R'*cfg.lite_magnetic_ned_gauss(:)+cfg.magnetometer_bias_gauss(:))'+noise.mag(k,:);
memory.baro(slot)=-state.position(3)+cfg.barometer_bias_m+noise.baro(k);
names={'gnss','baro','mag'};delays=[cfg.gnss_delay_s,cfg.barometer_delay_s,cfg.magnetometer_delay_s];rates=[cfg.gnss_hz,cfg.barometer_hz,cfg.magnetometer_hz];
for i=1:3
 source=k-round(delays(i)*cfg.sample_hz);fresh=source>=1 && mod(source-1,round(cfg.sample_hz/rates(i)))==0;
 item=struct('fresh',fresh,'source_time_s',(source-1)/cfg.sample_hz);
 if fresh
  old=mod(source-1,memory.length)+1;
  if i==1,item.position=memory.position(old,:)';item.velocity=memory.velocity(old,:)';
  elseif i==2,item.height=memory.baro(old);else,item.field=memory.mag(old,:)';end
 end
 messages.(names{i})=item;
end
end
