function ppid_write_track(folder,L,ref,seed)
% 100Hz轨迹仅用于绘图；评分仍使用完整800Hz真值日志。
keep=1:8:numel(L.time_s);T=table(L.time_s(keep),'VariableNames',{'time_s'});
actual=[L.position,L.velocity,rad2deg(L.euler),rad2deg(L.omega)];
estimated=[L.estimated_position,L.estimated_velocity,rad2deg(L.estimated_euler),rad2deg(L.measured_omega)];
target=[ref.position_ned_m,ref.velocity_ned_m_s,rad2deg(ref.euler_rad),rad2deg(ref.omega_body_rad_s)];
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];
for i=1:12
    T.("actual_"+names(i))=actual(keep,i);T.("estimate_"+names(i))=estimated(keep,i);T.("target_"+names(i))=target(keep,i);
end
T.lambda=L.lambda(keep);T.mode=L.mode(keep);
for j=1:3,T.("gamma_sp_"+string(j))=L.gamma_sp(keep,j);T.("gamma_ff_"+string(j))=L.gamma_ff(keep,j);end
writetable(T,fullfile(folder,'tracks',sprintf('%s_s%d.csv',L.name,seed)));
end
