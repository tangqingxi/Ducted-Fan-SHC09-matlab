function px4 = px4_log_view(log,model,cfg)
% 离线命名视图：只读已记录的数值，不订阅总线、不调用仿真或修改控制链。
if nargin<2,model=struct();end
if nargin<3,cfg=struct();end
assert(isstruct(log)&&isscalar(log)&&isstruct(model)&&isstruct(cfg),'shc09:Px4Input','输入必须为值结构。');
if isfield(log,'time_for_metrics'),t=log.time_for_metrics;elseif isfield(log,'time_s'),t=log.time_s;else,error('shc09:Px4Time','日志缺少原始time_for_metrics/time_s。');end
t=t(:);n=numel(t);assert(n>0&&isnumeric(t)&&all(isfinite(t))&&all(t>=0)&&all(diff(t)>0)&&all(t*1e6<=flintmax),'shc09:Px4Time','时间必须有限、非负、严格递增且可精确表示微秒整数。');
C=[0,1,0;-1,0,0;0,0,1];stamp=uint64(round(t*1e6));
px4=struct('timestamp_us',stamp,'time_s',t);raw=struct();
if isfield(log,'rotation')
 R=log.rotation;
 if n==1&&isequal(size(R),[3,3]),R=reshape(R,1,3,3);end
 if isequal(size(R),[3,3,n])&&~isequal(size(R),[n,3,3]),R=permute(R,[3,1,2]);end
 assert(size(R,1)==n&&size(R,2)==3&&size(R,3)==3,'shc09:Px4Shape','rotation应为N×3×3；也接受无歧义的3×3×N。');
 rotation_source="log.rotation";
else
 angles=field(log,'euler_rad',3);R=NaN(n,3,3);
 for k=1:n,if all(isfinite(angles(k,:))),R(k,:,:)=ca_euler_rotation(angles(k,:)');end,end
 rotation_source="log.euler_rad重建的已记录物理姿态";
end
q=NaN(n,4);
for k=1:n
 r=reshape(R(k,:,:),3,3);
 if all(isfinite(r),'all')
  assert(norm(r*r'-eye(3),'fro')<1e-6&&abs(det(r)-1)<1e-6,'shc09:Px4Rotation','输入不是正交旋转矩阵。');
  q(k,:)=quaternion(r*C');
 end
end
raw.rotation=R;raw.position_ned=field(log,'position_ned_m',3);raw.velocity_ned=field(log,'velocity_ned_m_s',3);
raw.omega=field(log,'omega_rad_s',3);raw.v_h=field(log,'v_h',3);raw.v_c=field(log,'v_c',3);raw.alpha_total=raw.v_h+raw.v_c;
raw.alpha=field(log,'true_alpha_rad_s2',3);raw.command_rad=field(log,'command_rad',6);raw.vane_deg=rad2deg(raw.command_rad);
raw.actual_vane_deg=rad2deg(field(log,'actual_delta_rad',6));raw.motor_rad_s=field(log,'motor_rad_s',1);raw.motor_command_rad_s=field(log,'motor_command_rad_s',1);
raw.measured_euler_rad=field(log,'measured_euler_rad',3);raw.measured_omega_rad_s=field(log,'measured_omega_rad_s',3);
raw.estimated_position_ned=field(log,'estimated_position_ned_m',3);raw.estimated_velocity_ned=field(log,'estimated_velocity_ned_m_s',3);
raw.aero_torque_nm=field(log,'aero_torque_nm',3);raw.disturbance_torque_nm=field(log,'disturbance_torque_nm',3);
J=NaN(3);if isfield(model,'inertia'),J=model.inertia;elseif isfield(model,'J'),J=model.J;end
assert(isequal(size(J),[3,3])&&(all(isfinite(J),'all')||all(isnan(J),'all')),'shc09:Px4Model','名义惯量必须为3×3。');
raw.torque_nm=raw.alpha_total*J';
px4.vehicle_attitude=struct('timestamp',stamp,'q',q);
px4.vehicle_local_position=struct('timestamp',stamp,'x',raw.position_ned(:,1),'y',raw.position_ned(:,2),'z',raw.position_ned(:,3), ...
 'vx',raw.velocity_ned(:,1),'vy',raw.velocity_ned(:,2),'vz',raw.velocity_ned(:,3));
px4.vehicle_angular_velocity=struct('timestamp',stamp,'xyz',raw.omega*C');
px4.vehicle_angular_acceleration=struct('timestamp',stamp,'xyz',raw.alpha*C');
px4.vehicle_torque_setpoint=struct('timestamp',stamp,'xyz',raw.torque_nm*C');
% 静态风扇推力代理，不混入气动升阻力；最大转速对应推力作为无量纲基准。
kT=NaN;maximum=NaN;
if isfield(model,'k_T0'),kT=model.k_T0;end
if isfield(model,'omega_m_max'),maximum=model.omega_m_max;end
if isfield(model,'parameters')
 p=model.parameters;
 if isfield(p,'Duct')&&isfield(p.Duct,'k_T0'),kT=p.Duct.k_T0;end
 if isfield(p,'omega_m_max'),maximum=p.omega_m_max;end
end
assert(isscalar(kT)&&isscalar(maximum),'shc09:Px4Model','推力系数和最大转速必须为标量。');
reference=NaN;raw.thrust_n=NaN(n,1);
if isfinite(kT)&&kT>0,raw.thrust_n=kT*raw.motor_rad_s.^2;end
if isfinite(kT)&&kT>0&&isfinite(maximum)&&maximum>0,reference=kT*maximum^2;end
raw.thrust_body_n=[zeros(n,2),-raw.thrust_n];
px4.vehicle_thrust_setpoint=struct('timestamp',stamp,'xyz',raw.thrust_body_n*C'/reference);
% 只对导出控制量限幅，原命令和未限幅归一化值始终保留。
lower=NaN(1,6);upper=lower;
if isfield(model,'command_lower')&&isfield(model,'command_upper')
 lower=reshape(model.command_lower,1,[]);upper=reshape(model.command_upper,1,[]);
 assert(numel(lower)==6&&numel(upper)==6&&all(isfinite([lower,upper]))&&all(upper>lower),'shc09:Px4Model','舵机上下界必须是六维有效区间。');
end
raw.servo_control_unclipped=2*(raw.command_rad-lower)./(upper-lower)-1;
raw.servo_out_of_range=abs(raw.servo_control_unclipped)>1;
control=max(-1,min(1,raw.servo_control_unclipped));control(~isfinite(raw.servo_control_unclipped))=NaN;
px4.actuator_servos=struct('timestamp',stamp,'control',control);
% 传感器只取原始测量；有topic时仅把同一发布时刻的新观测写入宽表，不保持或插值。
[accel,imu_time]=samples('sensor_imu','accel',3,false,'sample_time_s');[gyro,gyro_time]=samples('sensor_imu','gyro',3,false,'sample_time_s');
if isfield(log,'raw_specific_force_m_s2'),accel=field(log,'raw_specific_force_m_s2',3);end
if isfield(log,'raw_gyro_rad_s'),gyro=field(log,'raw_gyro_rad_s',3);end
if isfield(log,'imu_sample_time_s'),imu_time=field(log,'imu_sample_time_s',1);gyro_time=imu_time;end
[mag,mag_time]=samples('sensor_mag','field',3,true,'source_time_s');
if isfield(log,'raw_mag_gauss'),mag=field(log,'raw_mag_gauss',3);end
[baro,baro_time]=samples('sensor_baro','height',1,true,'source_time_s');
[pressure,~]=samples('sensor_baro','pressure_pa',1,true,'source_time_s');
[gps,gps_time]=samples('sensor_gnss','position',3,true,'source_time_s');
if isfield(log,'baro_height_m'),baro=field(log,'baro_height_m',1);end
if isfield(log,'baro_pressure_pa'),pressure=field(log,'baro_pressure_pa',1);end
if isfield(log,'mag_sample_time_s'),mag_time=field(log,'mag_sample_time_s',1);end
if isfield(log,'baro_sample_time_s'),baro_time=field(log,'baro_sample_time_s',1);end
if isfield(log,'gnss_sample_time_s'),gps_time=field(log,'gnss_sample_time_s',1);end
if isfield(log,'gnss_position_ned_m'),gps=field(log,'gnss_position_ned_m',3);end
raw.accel=accel;raw.gyro=gyro;raw.mag=mag;raw.gnss_position_ned=gps;
raw.imu_sample_time_s=imu_time;raw.mag_sample_time_s=mag_time;raw.baro_sample_time_s=baro_time;raw.gnss_sample_time_s=gps_time;
raw.baro_height_m=baro;raw.baro_pressure_pa=pressure;
px4.sensor_accel=sensor(accel*C',imu_time);px4.sensor_gyro=sensor(gyro*C',gyro_time);px4.sensor_mag=sensor(mag*C',mag_time);
px4.sensor_baro=sensor([],baro_time);px4.sensor_baro.height=baro;px4.sensor_baro.pressure_pa=pressure;
latitude=NaN(n,1);longitude=latitude;altitude=latitude;
origin_available=isfield(cfg,'navigation_origin')&&numel(cfg.navigation_origin)==3&&all(isfinite(cfg.navigation_origin));
if origin_available
 origin=cfg.navigation_origin(:);assert(abs(origin(1))<=90&&abs(origin(2))<=180,'shc09:Px4Origin','原点经纬度无效。');
 % 球面方位等距反投影，地球半径与归档ECL的本地投影约定一致。
 radius=6371000;lat0=deg2rad(origin(1));lon0=deg2rad(origin(2));
 north=gps(:,1)/radius;east=gps(:,2)/radius;distance=hypot(north,east);scale=ones(n,1);nz=distance>0;scale(nz)=sin(distance(nz))./distance(nz);
 latitude=asin(max(-1,min(1,cos(distance)*sin(lat0)+north.*scale*cos(lat0))));
 longitude=lon0+atan2(east.*scale,cos(lat0)*cos(distance)-north.*scale*sin(lat0));
 latitude=rad2deg(latitude);longitude=rad2deg(atan2(sin(longitude),cos(longitude)));altitude=origin(3)-gps(:,3);
 % 缺测不能被三角函数的缺失值处理变成有效坐标。
 invalid=~all(isfinite(gps),2);latitude(invalid)=NaN;longitude(invalid)=NaN;altitude(invalid)=NaN;
end
px4.sensor_gps=sensor([],gps_time);px4.sensor_gps.lat=latitude;px4.sensor_gps.lon=longitude;px4.sensor_gps.alt=altitude;
px4.shc09=raw;
px4.meta=struct('schema',"shc09-px4-named-view-v1",'body_to_frd',C,'attitude_source',rotation_source, ...
 'state_source',"已记录物理状态；测量/估计值另留shc09原始列",'torque_unit',"Nm，名义J换算；区别于PX4归一化消息", ...
 'thrust_reference_n',reference,'thrust_source',"实际motor_rad_s的静态推力代理，非气动总力或原生推力指令", ...
 'thrust_missing_reason',"缺少正k_T0时推力NaN；缺少正最大转速时归一化基准NaN", ...
 'gnss_origin_available',origin_available,'gps_units',"lat/lon为度，alt为米；球面方位等距反投影", ...
 'sensor_alignment',"同一控制时刻的新测量；不插值。未知/负采样秒的timestamp_sample为0且valid=false", ...
 'rotation_layout',"N×3×3，CSV按MATLAB列主序扁平化",'firmware_compatible',false);

 function value=field(s,name,width)
  value=NaN(n,width);if ~isfield(s,name),return;end
  value=s.(name);assert(isnumeric(value)&&isequal(size(value),[n,width]),'shc09:Px4Shape','字段%s必须为N×%d。',name,width);
 end
 function [value,sample_time]=samples(topic,key,width,fresh,time_key)
  value=NaN(n,width);sample_time=NaN(n,1);
  if ~isfield(log,'topic_log')||~isfield(log.topic_log,topic),return;end
  history=log.topic_log.(topic);[matched,index]=ismembertol(history.time_s(:),t,1e-9,'DataScale',1);
  for j=find(matched)'
   data=history.data{j};if fresh&&(~isfield(data,'fresh')||~data.fresh),continue;end
   i=index(j);
   if isfield(data,key),v=data.(key);assert(numel(v)==width,'shc09:Px4Shape','传感器宽度不符。');value(i,:)=reshape(v,1,width);end
   if isfield(data,time_key),sample_time(i)=data.(time_key);end
  end
 end
 function value=sensor(x,sample_time)
  valid=isfinite(sample_time)&sample_time>=0&sample_time*1e6<=flintmax;sample_stamp=zeros(n,1,'uint64');sample_stamp(valid)=uint64(round(sample_time(valid)*1e6));
  value=struct('timestamp',stamp,'timestamp_sample',sample_stamp,'timestamp_sample_valid',valid);
  if ~isempty(x),value.xyz=x;end
 end
end

function q=quaternion(R)
% 按最大分量分支避免接近一百八十度时除以接近零的标量部。
candidates=[1+trace(R),1+R(1,1)-R(2,2)-R(3,3),1-R(1,1)+R(2,2)-R(3,3),1-R(1,1)-R(2,2)+R(3,3)];
[~,i]=max(candidates);a=sqrt(max(0,candidates(i)))/2;s=4*a;
switch i
 case 1,q=[a,(R(3,2)-R(2,3))/s,(R(1,3)-R(3,1))/s,(R(2,1)-R(1,2))/s];
 case 2,q=[(R(3,2)-R(2,3))/s,a,(R(1,2)+R(2,1))/s,(R(1,3)+R(3,1))/s];
 case 3,q=[(R(1,3)-R(3,1))/s,(R(1,2)+R(2,1))/s,a,(R(2,3)+R(3,2))/s];
 case 4,q=[(R(2,1)-R(1,2))/s,(R(1,3)+R(3,1))/s,(R(2,3)+R(3,2))/s,a];
end
q=q/norm(q);if q(1)<0,q=-q;end
end
