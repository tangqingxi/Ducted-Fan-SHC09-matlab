function s = shc09_estimator_lite_module(bus,s,p,time_s)
% Mahony式旋转观察器，仅订阅原始测量；无state或真值入口。
baro=bus.subscribe('sensor_baro');u=bus.subscribe('sensor_imu');mag=bus.subscribe('sensor_mag');gps=bus.subscribe('sensor_gnss');
if isempty(s),s=struct('initialized',false,'bias',zeros(3,1),'last_time',time_s,'last_gps',-Inf,'position',zeros(3,1),'velocity',zeros(3,1));end
if ~all(isfinite([u.gyro;u.accel])) || norm(u.accel)<1e-3
 bus.publish('estimator_health',struct('valid',false,'reason',"invalid_imu"),time_s);return;
end
if mag.fresh,s.mag=mag.field;end
if gps.fresh,s.last_gps=time_s;end
if ~isfield(s,'mag') || ~all(isfinite(s.mag)) || norm(s.mag)<1e-6
 bus.publish('estimator_health',struct('valid',false,'reason',"missing_mag"),time_s);return;
end
z=-u.accel/norm(u.accel);m=p.lite_magnetic_ned_gauss(:);m=m/norm(m);
if ~s.initialized
 x=s.mag-z*(z'*s.mag);x=x/norm(x);y=cross(z,x);
 north=m-[0;0;m(3)];north=north/norm(north);
 s.rotation=[north,cross([0;0;1],north),[0;0;1]]*[x,y,z]';s.initialized=true;
end
dt=max(0,time_s-s.last_time);s.last_time=time_s;
earth=7.292115e-5*[cosd(p.navigation_origin(1));0;-sind(p.navigation_origin(1))];
rate=u.gyro-s.bias-s.rotation'*earth;
s.rotation=s.rotation*ca_rotation_increment(rate*dt);
accel_innovation=cross(z,s.rotation'*[0;0;1]);
% 仅诊断显式启用时门控加计修正；标准路径保持原运算顺序。
if isfield(p,'diagnosis_accel_gate_enabled') && p.diagnosis_accel_gate_enabled
 if abs(norm(u.accel)-p.lite_gravity_m_s2)>=p.diagnosis_accel_gate_m_s2 || norm(u.gyro)>=p.diagnosis_rate_gate_rad_s
  accel_innovation=zeros(3,1);
 end
end
innovation=accel_innovation+cross(s.mag/norm(s.mag),s.rotation'*m);
s.bias=s.bias-p.lite_attitude_ki*innovation*dt;
s.rotation=s.rotation*ca_rotation_increment(p.lite_attitude_kp*innovation*dt);
% 简化惯导互补：用估计姿态旋转比力，再融合延迟补偿的定位/气压观测。
if ~isfield(s,'position_initialized'),s.position_initialized=false;end
if s.position_initialized
 acceleration=s.rotation*u.accel+[0;0;p.lite_gravity_m_s2];
 s.position=s.position+s.velocity*dt+0.5*acceleration*dt^2;s.velocity=s.velocity+acceleration*dt;
end
if gps.fresh && gps.source_time_s<=time_s+1e-9 && all(isfinite([gps.position;gps.velocity]))
 age=max(0,time_s-gps.source_time_s);observed=gps.position+gps.velocity*age;
 if ~s.position_initialized
  s.position=observed;s.velocity=gps.velocity;s.position_initialized=true;s.gps_update=time_s;
 else
  interval=time_s-s.gps_update;s.gps_update=time_s;
  s.position=s.position+(1-exp(-interval/p.lite_position_tau_s))*(observed-s.position);
  s.velocity=s.velocity+(1-exp(-interval/p.lite_velocity_tau_s))*(gps.velocity-s.velocity);
 end
elseif gps.fresh
 bus.publish('estimator_health',struct('valid',false,'reason',"invalid_gnss"),time_s);return;
end
if baro.fresh && s.position_initialized
 if ~isfield(s,'baro_update'),s.baro_update=time_s;end
 interval=time_s-s.baro_update;s.baro_update=time_s;
 observed=-baro.height+s.velocity(3)*max(0,time_s-baro.source_time_s);
 s.position(3)=s.position(3)+(1-exp(-interval/p.lite_baro_tau_s))*(observed-s.position(3));
end
% 健康判断只能用可观测创新；真实误差只留在sim日志。
valid=s.position_initialized && all(isfinite([s.rotation(:);s.bias;s.position;s.velocity])) && norm(innovation)<p.lite_max_innovation_rad && time_s-s.last_gps<=p.lite_gnss_timeout_s;
bus.publish('vehicle_attitude',struct('rotation',s.rotation),time_s);
bus.publish('vehicle_local_position',struct('position',s.position,'velocity',s.velocity),time_s);
bus.publish('vehicle_angular_velocity',struct('omega',u.gyro-s.bias-s.rotation'*earth),time_s);
bus.publish('estimator_health',struct('valid',valid,'innovation_rad',norm(innovation),'reason',"measurement_health"),time_s);
end
