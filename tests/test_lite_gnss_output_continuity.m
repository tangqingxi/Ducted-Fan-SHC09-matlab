function report = test_lite_gnss_output_continuity()
% 仅使用合成原始测量验证修正连续性、总量和隔离，不引入物理状态或真值反馈。
c=ca_validate_config(ca_config());p=shc09_lite_params(c);bus=Shc09Bus();s=[];dt=1/c.sample_hz;
earth=7.292115e-5*[cosd(p.navigation_origin(1));0;-sind(p.navigation_origin(1))];
for k=0:round(0.2/dt)
 t=k*dt;fresh=k==0||k==round(0.2/dt);gps=struct('fresh',fresh,'source_time_s',t);
 if fresh
  gps.position=zeros(3,1);gps.velocity=zeros(3,1);
  if k>0,gps.position(1)=1;gps.velocity(1)=0.2;end
 end
 publish(t,gps);previous=s;s=shc09_estimator_lite_module(bus,s,p,t);
end
position_jump=norm(s.position-previous.position);velocity_jump=norm(s.velocity-previous.velocity);
position_total=1-exp(-0.2/p.lite_position_tau_s);velocity_total=0.2*(1-exp(-0.2/p.lite_velocity_tau_s));
assert(position_jump<0.005&&velocity_jump<0.005,'GNSS修正仍直接跳变。');
assert(abs(s.position(1)+s.gnss_position_correction(1)-position_total)<1e-12);
assert(abs(s.velocity(1)+s.gnss_velocity_correction(1)-velocity_total)<1e-12,'互补修正总量被意外修改。');
remaining=s.gnss_position_correction;
for k=1:round(0.2/dt)
 t=0.2+k*dt;publish(t,struct('fresh',false,'source_time_s',0.2));s=shc09_estimator_lite_module(bus,s,p,t);
 assert(bus.latest('estimator_health').valid&&all(isfinite([s.position;s.velocity])));
end
assert(norm(s.gnss_position_correction-exp(-2)*remaining)<1e-12);
assert(~bus.exists('plant_truth')&&~bus.exists('sensor_attitude')&&~bus.exists('sensor_local_position'));
report=struct('position_jump_m',position_jump,'velocity_jump_m_s',velocity_jump,'correction_conserved',true,'decay_correct',true,'truth_topics_absent',true);disp(report);
 function publish(t,gps)
  bus.publish('sensor_imu',struct('gyro',earth,'accel',[0;0;-p.lite_gravity_m_s2]),t);
  bus.publish('sensor_mag',struct('fresh',true,'field',p.lite_magnetic_ned_gauss),t);
  bus.publish('sensor_baro',struct('fresh',false,'source_time_s',t),t);bus.publish('sensor_gnss',gps,t);
 end
end
