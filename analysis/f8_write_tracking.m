function states=f8_write_tracking(L,ref,protocol,folder)
% 压力试验沿用共同几何十二状态指标；额外记录反馈修正指令，不混作共同目标。
target=[ref.position_ned_m,ref.velocity_ned_m_s,rad2deg(ref.euler_rad),rad2deg(ref.omega_body_rad_s)];
actual=[L.position_ned_m,L.velocity_ned_m_s,rad2deg(L.euler_rad),rad2deg(L.omega_rad_s)];
estimate=[L.estimated_position_ned_m,L.estimated_velocity_ned_m_s,rad2deg(L.measured_euler_rad),rad2deg(L.measured_omega_rad_s)];
error=actual-target;error(:,7:9)=rad2deg(atan2(sin(deg2rad(error(:,7:9))),cos(deg2rad(error(:,7:9)))));
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];states=table();
bounds=[0,ref.time_s(end);protocol.motion_window_s';protocol.cruise_window_s';0,6];windows=["whole","task","cruise","initial_hover"];
for wi=1:4
    q=ref.time_s>=bounds(wi,1)&ref.time_s<=bounds(wi,2);
    for k=1:12
        e=error(q,k);states=[states;table(string(L.name),protocol.seed,windows(wi),names(k),sqrt(mean(e.^2)),max(abs(e)), ...
            'VariableNames',{'method','seed','window','state','rmse','peak_abs'})];
    end
end
keep=1:8:numel(ref.time_s);T=array2table([ref.time_s(keep),target(keep,:),actual(keep,:),estimate(keep,:)], ...
    'VariableNames',cellstr(["time_s","target_"+names,"actual_"+names,"estimate_"+names]));
T.command_roll_deg=rad2deg(L.desired_euler_rad(keep,1));T.command_pitch_deg=rad2deg(L.desired_euler_rad(keep,2));
T.command_yaw_deg=rad2deg(L.desired_euler_rad(keep,3));
for k=1:3,T.("command_rate"+string(k)+"_deg_s")=rad2deg(L.omega_reference_rad_s(keep,k));end
writetable(T,fullfile(folder,'tracks',sprintf('%s_s%d.csv',L.name,protocol.seed)));
end
