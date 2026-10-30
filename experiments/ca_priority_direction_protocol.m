function protocol = ca_priority_direction_protocol(cfg,model,load_fraction,dwell_s)
% 按名义能力标定补偿方向，所有方向在运行前确定，不按算法结果挑选。
if nargin<4, dwell_s=8; end
assert(isscalar(dwell_s) && isfinite(dwell_s) && dwell_s>=3,'驻留时间须不少于三秒。');
C=model.torque_matrix; capacity=sum(abs(C).*model.command_upper',2);
A=C./capacity; options=optimoptions('linprog','Display','none');
angles=[0,35,-35]; moments=zeros(3,3); witnesses=zeros(6,3); fractions=zeros(3,1);
for k=1:3
    direction=[0;sind(angles(k));cosd(angles(k))];
    [solution,~,flag]=linprog([zeros(6,1);-1],[],[],[A,-direction],zeros(3,1), ...
        [model.command_lower;0],[model.command_upper;Inf],options);
    assert(flag>0,'补偿方向的射线能力标定失败。');
    fractions(k)=solution(7);
    moments(:,k)=load_fraction*solution(7)*capacity.*direction;
    witnesses(:,k)=load_fraction*solution(1:6);
    assert(norm(C*witnesses(:,k)-moments(:,k),Inf)<1e-10,'补偿可行证书错误。');
end
physical=ca_shc09_aerodynamics(eye(3),zeros(3,1),zeros(3,1),zeros(6,1), ...
    model.hover_motor_rad_s,model,cfg);
external=-moments-physical.passive_torque_body_nm;
times=4+(0:3)*dwell_s;
protocol=struct('angles_deg',angles,'moments_nm',moments,'external_nm',external, ...
    'witness_delta_rad',witnesses,'ray_capacity',fractions,'axis_capacity_nm',capacity, ...
    'load_fraction',load_fraction,'maneuver_window_s',[4,times(4)], ...
    'leg_windows_s',[times(1:3)',times(2:4)'],'settling_radius_m',0.2,'settling_speed_m_s',0.2, ...
    'settling_hold_s',0.5,'dwell_s',dwell_s,'return_s',times(4),'unload_s',times(4)+6, ...
    'duration_s',times(4)+12,'load_turn_times_s',[times(2)-2,times(3)-2]);
protocol.position_stages=[0,0,0,-10;times(1),0,2,-10;times(2),2,-2,-10;times(3),-2,2,-10;times(4),0,0,-10];
protocol.fixed_disturbance_stages=[0,0,0,0;2,external(:,1)';protocol.unload_s,0,0,0];
protocol.turning_disturbance_stages=[0,0,0,0;2,external(:,1)';protocol.load_turn_times_s(1),external(:,2)'; ...
    protocol.load_turn_times_s(2),external(:,3)';protocol.unload_s,0,0,0];
end
