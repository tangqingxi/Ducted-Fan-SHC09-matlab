function s = shc09_estimator_lite_module(bus,s,p,time_s)
% Mahony式旋转观察器，仅订阅原始测量；无state或真值入口。
u=bus.subscribe('sensor_imu');mag=bus.subscribe('sensor_mag');gps=bus.subscribe('sensor_gnss');
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
innovation=cross(z,s.rotation'*[0;0;1])+cross(s.mag/norm(s.mag),s.rotation'*m);
s.bias=s.bias-p.lite_attitude_ki*innovation*dt;
s.rotation=s.rotation*ca_rotation_increment(p.lite_attitude_kp*innovation*dt);
% 健康判断只能用可观测创新；真实误差只留在sim日志。
valid=all(isfinite([s.rotation(:);s.bias])) && norm(innovation)<p.lite_max_innovation_rad && time_s-s.last_gps<=p.lite_gnss_timeout_s;
bus.publish('vehicle_attitude',struct('rotation',s.rotation),time_s);
bus.publish('vehicle_local_position',struct('position',s.position,'velocity',s.velocity),time_s);
bus.publish('vehicle_angular_velocity',struct('omega',u.gyro-s.bias-s.rotation'*earth),time_s);
bus.publish('estimator_health',struct('valid',valid,'innovation_rad',norm(innovation),'reason',"measurement_health"),time_s);
end
