function row = ca_mismatch_metrics(log,model,case_id,window_name,window_s)
% 所有误差使用物理真值；饱和率指评价窗内任一PWM命令触及公共位置限幅。
selected=log.time_for_metrics>=window_s(1) & log.time_for_metrics<=window_s(2);
events=log.pwm_update_time_s>=window_s(1) & log.pwm_update_time_s<=window_s(2);
commands=rad2deg(log.pwm_command_rad(events,:)); changes=diff(commands);
step=NaN; peak=NaN; saturation=NaN;
if ~isempty(commands)
    peak=max(abs(commands),[],'all');
    saturation=100*mean(any(abs(commands)>=rad2deg(model.command_upper)'-1e-5,2));
end
if ~isempty(changes), step=sqrt(mean(changes.^2,'all')); end
position=log.position_ned_m(selected,:)-log.position_reference_ned_m(selected,:);
error_nm=log.moment_model_error_nm(selected);
pca=startsWith(string(log.name),"PCA"); mode1=NaN; mode2=NaN;
if pca
    mode1=100*mean(log.mode(selected)==1); mode2=100*mean(log.mode(selected)==2);
end
row=table(string(case_id),string(log.name),string(window_name), ...
    sqrt(mean(error_nm.^2)),max(error_nm),saturation,mode1,mode2, ...
    sqrt(mean(rad2deg(log.rotation_error_rad(selected)).^2)), ...
    sqrt(mean(rad2deg(log.euler_error_rad(selected,3)).^2)), ...
    sqrt(mean(sum(position.^2,2))),step,peak,100*mean(log.table_extrapolated(selected)), ...
    sum(log.solver_exitflag(selected)<=0),sum(log.solver_rescue(selected)),sum(log.restore_solver_rescue(selected)), ...
    'VariableNames',{'case_id','method','window','moment_model_error_rms_nm','moment_model_error_max_nm', ...
    'saturation_percent','mode1_percent','mode2_percent','attitude_rmse_deg','yaw_rmse_deg', ...
    'position_rmse_m','command_step_rms_deg','max_pwm_command_deg','aero_extrapolated_percent', ...
    'solver_nonoptimal_count','solver_rescue_count','restore_solver_rescue_count'});
row.low_speed_regularized_percent=100*mean(log.low_speed_regularized(selected));
% 保留原位置列含义，仅另加角色说明。
row.position_metric_role="secondary";
end
