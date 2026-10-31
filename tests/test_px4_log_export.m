function report = test_px4_log_export()
% 合成非对角惯量与边界姿态定位转换错误，再用两秒实际日志验收只读导出。
root=ca_setup();out=fullfile(root,'results','px4_log_export_'+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));mkdir(out);
C=[0,1,0;-1,0,0;0,0,1];assert(norm(C*C'-eye(3),'fro')==0&&det(C)==1);
n=8;t=(0:n-1)'/100;t(2)=t(2)+eps(t(2));L=struct('time_s',t,'rotation',zeros(n,3,3));
angles=[0,0,0;pi,0,0;0,pi,0;0,0,pi;pi-1e-9,0,0;0.2,-0.3,0.7;-1,0.6,-2;0,pi/2,0];
for i=1:n,L.rotation(i,:,:)=ca_euler_rotation(angles(i,:)')*C;end
L.position_ned_m=reshape(1:3*n,n,3);L.velocity_ned_m_s=-L.position_ned_m/10;
L.omega_rad_s=repmat([1,2,3],n,1);L.true_alpha_rad_s2=repmat([4,5,6],n,1);
L.v_h=repmat([1,2,3],n,1);L.v_c=repmat([-.2,.4,-.6],n,1);
model=struct('inertia',[2,.1,.2;.1,3,.05;.2,.05,4],'k_T0',0.01,'omega_m_max',100, ...
 'command_lower',(-1:-1:-6)'/10,'command_upper',(2:7)'/10);
L.command_rad=model.command_lower'+(0:n-1)'/(n-1).*(model.command_upper-model.command_lower)';
L.actual_delta_rad=0.9*L.command_rad;L.motor_rad_s=50*ones(n,1);
L.raw_specific_force_m_s2=repmat([3,-2,-9],n,1);L.raw_gyro_rad_s=repmat([.1,.2,.3],n,1);
imu=cell(n,1);mag=imu;baro=imu;gps=imu;
for i=1:n
 imu{i}=struct('accel',L.raw_specific_force_m_s2(i,:)','gyro',L.raw_gyro_rad_s(i,:)','sample_time_s',t(i)-.001);
 fresh=ismember(i,[1,4,7]);mag{i}=struct('fresh',fresh,'source_time_s',t(i)-.002,'field',[.2;.3;.4]);
 baro{i}=struct('fresh',fresh,'source_time_s',t(i)-.003,'height',10+i);
 gps{i}=struct('fresh',fresh,'source_time_s',t(i)-.01,'position',[10*(i-1);20*(i-1);-3*(i-1)]);
end
baro{4}.pressure_pa=100000;L.topic_log=struct();
for item={ {'sensor_imu',imu},{'sensor_mag',mag},{'sensor_baro',baro},{'sensor_gnss',gps} }
 pair=item{1};L.topic_log.(pair{1})=struct('time_s',t,'data',{pair{2}});
end
cfg=struct('navigation_origin',[47;8;500]);before=L;p=px4_log_view(L,model,cfg);assert(isequaln(L,before));
assert(max(abs(vecnorm(p.vehicle_attitude.q,2,2)-1))<1e-12&&all(p.vehicle_attitude.q(:,1)>=0));
errors=zeros(n,1);
for i=1:n,errors(i)=norm(ca_quaternion_rotation(p.vehicle_attitude.q(i,:))*C-reshape(L.rotation(i,:,:),3,3),'fro');end
assert(max(errors)<1e-10,'FRD四元数往返改变旋转。');
assert(isequal([p.vehicle_local_position.x,p.vehicle_local_position.y,p.vehicle_local_position.z],L.position_ned_m));
assert(isequal([p.vehicle_local_position.vx,p.vehicle_local_position.vy,p.vehicle_local_position.vz],L.velocity_ned_m_s));
assert(isequal(p.vehicle_angular_velocity.xyz,L.omega_rad_s*C')&&isequal(p.vehicle_angular_acceleration.xyz,L.true_alpha_rad_s2*C'));
tau=((model.inertia*(L.v_h+L.v_c)')');assert(norm(p.vehicle_torque_setpoint.xyz-tau*C','fro')<1e-12);
assert(isa(p.timestamp_us,'uint64')&&isequal(p.timestamp_us,uint64(round(t*1e6)))&&all(diff(double(p.timestamp_us))>=0)&&isequal(p.time_s,t));
assert(max(abs(p.actuator_servos.control(1,:)+1))<1e-12&&max(abs(p.actuator_servos.control(end,:)-1))<1e-12);
assert(isequal(p.shc09.v_h,L.v_h)&&isequal(p.shc09.v_c,L.v_c)&&isequal(p.shc09.rotation,L.rotation));
assert(all(p.shc09.thrust_n==25)&&p.meta.thrust_reference_n==100&&max(abs(p.vehicle_thrust_setpoint.xyz(:,3)+.25))<1e-12);
assert(isequal(p.sensor_accel.xyz,L.raw_specific_force_m_s2*C')&&isequal(p.sensor_gyro.xyz,L.raw_gyro_rad_s*C'));
assert(isequal(p.sensor_mag.xyz(4,:),[.3,-.2,.4])&&all(isnan(p.sensor_mag.xyz(2,:))));
assert(~p.sensor_gyro.timestamp_sample_valid(1)&&p.sensor_gyro.timestamp_sample(4)==uint64(29000));
assert(p.sensor_mag.timestamp_sample(4)==uint64(28000)&&p.shc09.gnss_sample_time_s(1)==-.01);
assert(abs(p.sensor_gps.lat(1)-47)<1e-10&&abs(p.sensor_gps.lon(1)-8)<1e-10&&p.sensor_gps.alt(1)==500);
assert(p.sensor_gps.lat(4)>47&&p.sensor_gps.lon(4)>8&&p.sensor_gps.alt(4)==509);
assert(p.sensor_baro.pressure_pa(4)==100000&&isnan(p.sensor_baro.pressure_pa(1)));
missing=px4_log_view(L,struct(),struct());
assert(all(isnan(missing.vehicle_torque_setpoint.xyz),'all')&&all(isnan(missing.vehicle_thrust_setpoint.xyz),'all')&&all(isnan(missing.actuator_servos.control),'all'));
assert(all(isnan(missing.sensor_gps.lat))&&isequaln(missing.shc09.gnss_position_ned,p.shc09.gnss_position_ned));
single=px4_log_view(struct('time_s',0,'rotation',eye(3)));assert(abs(norm(single.vehicle_attitude.q)-1)<1e-12);
limited=L;limited.command_rad(1,1)=model.command_lower(1)-.1;v=px4_log_view(limited,model,cfg);
assert(v.actuator_servos.control(1,1)==-1&&v.shc09.servo_out_of_range(1,1)&&v.shc09.command_rad(1,1)==limited.command_rad(1,1));
no_reference=px4_log_view(L,rmfield(model,'omega_m_max'),cfg);assert(all(no_reference.shc09.thrust_n==25)&&all(isnan(no_reference.vehicle_thrust_setpoint.xyz),'all'));
flat=rmfield(L,'topic_log');flat.baro_height_m=(1:n)';flat.baro_pressure_pa=100000*ones(n,1);flat.baro_sample_time_s=t;
v=px4_log_view(flat,model,cfg);assert(isequal(v.sensor_baro.height,flat.baro_height_m)&&isequal(v.sensor_baro.pressure_pa,flat.baro_pressure_pa)&&all(v.sensor_baro.timestamp_sample_valid));
files=px4_log_export(L,fullfile(out,'synthetic'),model,cfg);T=readtable(files.csv_path,'VariableNamingRule','preserve');
needed=["timestamp_us","time_s","vehicle_attitude.q0","vehicle_attitude.q3","vehicle_local_position.x","vehicle_local_position.vz", ...
 "vehicle_angular_velocity.xyz0","vehicle_torque_setpoint.xyz2","actuator_servos.control0","actuator_servos.control5","shc09.v_h0","shc09.v_c2","sensor_gyro.timestamp_sample"];
assert(all(ismember(needed,string(T.Properties.VariableNames)))&&height(T)==n);
assert(isequal(T.time_s,t)&&isequal(T.("vehicle_attitude.q0"),p.vehicle_attitude.q(:,1)),'CSV浮点精度未能保留原时间或姿态。');
d=load(files.mat_path,'px4');assert(isequaln(d.px4,p));
% 实际两秒位置保持日志，保留其原始参考时间；不启动完整主比较。
c=ca_config();overrides=shc09_airframe("ideal");for name=reshape(string(fieldnames(overrides)),1,[]),c.(name)=overrides.(name);end;c.duration_s=2;c.save_results=false;c.save_figures=false;c.show_figures=false;c=ca_validate_config(c);
m=ca_model(c);r=ca_reference(c);log=ca_simulate(m,c,r,"DA_NS");signature=shc09_log_signature(log);
input=fullfile(out,'input_log.mat');save(input,'log','c','r','-v7');
actual=px4_log_export(input,fullfile(out,'smoke'));assert(isequaln(signature,shc09_log_signature(log)));
d=load(actual.mat_path,'px4');assert(isequal(d.px4.time_s,r.time_s)&&max(abs(vecnorm(d.px4.vehicle_attitude.q,2,2)-1))<1e-12);
assert(~any(endsWith(string({dir(fullfile(out,'**','*')).name}),'.ulg')));
report=struct('quaternion_round_trip_max',max(errors),'synthetic_rows',n,'smoke_rows',actual.rows,'csv',actual.csv_path,'mat',actual.mat_path, ...
 'ned_unchanged',true,'nominal_torque_correct',true,'missing_values_preserved',true,'sensor_timestamps_checked',true,'input_log_unchanged',true,'csv_double_round_trip_exact',true,'ulog_dependency',false);
disp(report);
end
