function checks=test_hover_distance_protocol()
% 独立差分检查参考运动学，并检查父配置、外扰范围和相同随机输入。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
[c,m,r,p,s]=hd_config(501,.85,280);[original,old_model,~,parent]=ppid_config(501);
assert(isequaln(p.controller,parent.controller)&&isequaln(p.sensors,parent.sensors)&&isequaln(m,old_model));
for field=["tau_actual_s","tau_model_s","pwm_hz","sample_hz","rate_limit_deg_s","vane_gain_scale", ...
    "gyro_noise_std_deg_s","accelerometer_noise_std_m_s2","gnss_hz","barometer_hz","magnetometer_hz","navigation_warmup_s"]
    assert(isequaln(c.(field),original.(field)));
end
assert(numel(r.time_s)==32001&&all(r.position_ned_m==[0,0,-10],'all'));
assert(all(r.euler_rad(:,1:2)==0,'all')&&all(r.omega_body_rad_s(:,1:2)==0,'all'));
dt=1/800;ix=3:31999;
numerical=(r.euler_rad(ix-2,3)-8*r.euler_rad(ix-1,3)+8*r.euler_rad(ix+1,3)-r.euler_rad(ix+2,3))/(12*dt);
rate_error=max(abs(numerical-r.omega_body_rad_s(ix,3)));assert(rate_error<1e-6);
numerical=(r.omega_body_rad_s(ix-2,3)-8*r.omega_body_rad_s(ix-1,3)+8*r.omega_body_rad_s(ix+1,3)-r.omega_body_rad_s(ix+2,3))/(12*dt);
gamma_error=max(abs(numerical-r.alpha_body_rad_s2(ix,3)));assert(gamma_error<1e-5);
series=c.disturbance_series;assert(all(series.torque_nm(:,2:3)==0,'all'));
outside=series.time_s<10|series.time_s>=22.5;assert(max(abs(series.torque_nm(outside,1)))<1e-12);
assert(abs(max(abs(series.torque_nm(:,1)))-s.roll_disturbance_amplitude_nm)<1e-10);
assert(isempty(c.disturbance_stages_nm)&&all(c.disturbance_torque_nm==0));
for time=[0,9.5,10.2,11.3,22.2,23,40]
    assert(max(abs(ca_disturbance_torque(time,c)-[interp1(series.time_s,series.torque_nm(:,1),time);0;0]))<1e-12);
end
e1=ppid_noise(c,r,p);e2=ppid_noise(c,r,p);e1.disturbance_series=series;e2.disturbance_series=series;
assert(allocation_comparison_hash(e1)==allocation_comparison_hash(e2));
checks=struct('rate_reference_max_error',rate_error,'gamma_reference_max_error',gamma_error, ...
    'parent_controller_unchanged',true,'parent_sensors_unchanged',true,'axis_capacity_nm',s.axis_capacity_nm, ...
    'roll_amplitude_nm',s.roll_disturbance_amplitude_nm,'random_inputs_identical',true,'flight_simulations_run',0);
disp(checks);
end
