function hd_write_track(output,L,ref,seed)
% 100Hz时序供可视化，正式误差用完整800Hz，分配事件用400Hz。
keep=1:8:numel(L.time_s);T=table(L.time_s(keep),'VariableNames',{'time_s'});
for j=1:3
    T.("estimated_position_"+j)=L.estimated_position(keep,j);T.("true_position_"+j)=L.position(keep,j);
    T.("reference_position_"+j)=ref.position_ned_m(keep,j);
    T.("estimated_euler_"+j)=rad2deg(L.estimated_euler(keep,j));T.("true_euler_"+j)=rad2deg(L.euler(keep,j));
    T.("measured_rate_"+j)=rad2deg(L.measured_omega(keep,j));T.("reference_rate_"+j)=rad2deg(ref.omega_body_rad_s(keep,j));
end
T.lambda=L.lambda(keep);T.mode=L.mode(keep);
writetable(T,fullfile(output,'tracks',sprintf('%s_s%d.csv',L.name,seed)));
end
