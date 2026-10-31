function row = estimator_feedback_metrics_row(L,m,experiment,mode,seed,window,bounds)
% 离线统一窗口指标；分配需求为角加速度单位，不误称牛米。
q=L.time_for_metrics>=bounds(1) & L.time_for_metrics<=bounds(2);
p=L.pwm_update_time_s>=bounds(1) & L.pwm_update_time_s<=bounds(2);
row=ca_mismatch_metrics(L,m,experiment,window,bounds);row.estimator_mode=mode;row.seed=seed;
row.window_start_s=bounds(1);row.window_end_s=bounds(2);
row.rate_rmse_deg_s=sqrt(mean(sum(rad2deg(L.rate_error_rad_s(q,:)).^2,2)));
demand=L.v_h+L.v_c;allocation=L.command_rad*m.acceleration_matrix'-demand;
row.allocation_demand_error_rms_rad_s2=sqrt(mean(sum(allocation(q,:).^2,2)));
% 控制目标为角加速度；用名义惯量转换后另报牛米单位的预测力矩残差。
nominal_torque=allocation*m.parameters.J';
common_torque=L.common_predicted_delta_rad*m.torque_matrix'-demand*m.parameters.J';
row.nominal_command_torque_error_rms_nm=sqrt(mean(sum(nominal_torque(q,:).^2,2)));
row.common_predicted_torque_error_rms_nm=sqrt(mean(sum(common_torque(q,:).^2,2)));
row.simulation_elapsed_s=L.elapsed_s;
row.common_residual_rms=sqrt(mean(L.common_residual(q).^2));row.native_residual_rms=sqrt(mean(L.native_residual(q).^2));
changes=diff(rad2deg(L.pwm_command_rad(p,:)));row.command_total_variation_deg=sum(abs(changes),'all');
pe=rad2deg(L.pwm_end_prediction_error_rad(p & L.pwm_prediction_checked,:));row.prediction_rmse_deg=sqrt(mean(pe.^2,'all','omitnan'));
row.estimated_attitude_rmse_deg=0;row.estimated_position_rmse_m=0;row.bias_rmse_max_axis_deg_s=NaN;row.bias_final_max_axis_deg_s=NaN;
for name=["corr_position_allocation","corr_position_command","corr_position_tracking","corr_bias_allocation","corr_bias_command","corr_bias_tracking"]
 row.(name)=NaN;
end
row.corr_estimation_allocation=NaN;row.corr_estimation_command=NaN;row.corr_estimation_tracking=NaN;
if isfield(L,'estimated_attitude_error_rad')
 a=L.estimated_attitude_error_rad(q);row.estimated_attitude_rmse_deg=rad2deg(sqrt(mean(a.^2)));
 row.estimated_position_rmse_m=sqrt(mean(sum(L.estimated_position_error_m(q,:).^2,2)));
 b=rad2deg(L.estimated_gyro_bias_error_rad_s(q,:));row.bias_rmse_max_axis_deg_s=max(sqrt(mean(b.^2,1)));row.bias_final_max_axis_deg_s=max(abs(b(end,:)));
 activity=[zeros(1,6);diff(L.held_command_rad)];
 position=vecnorm(L.estimated_position_error_m(q,:),2,2);bias=vecnorm(b,2,2);
 row.corr_position_allocation=correlation(position,L.common_residual(q));
 row.corr_position_command=correlation(position,vecnorm(activity(q,:),2,2));
 row.corr_position_tracking=correlation(position,L.rotation_error_rad(q));
 row.corr_bias_allocation=correlation(bias,L.common_residual(q));
 row.corr_bias_command=correlation(bias,vecnorm(activity(q,:),2,2));
 row.corr_bias_tracking=correlation(bias,L.rotation_error_rad(q));
 row.corr_estimation_allocation=correlation(a,L.common_residual(q));
 row.corr_estimation_command=correlation(a,vecnorm(activity(q,:),2,2));
 row.corr_estimation_tracking=correlation(a,L.rotation_error_rad(q));
end
end
function rho=correlation(a,b)
% 数值精度内的常量序列无有意义相关系数，保留缺失值。
rho=NaN;if std(a)>1e-12 && std(b)>1e-12,C=corrcoef(a,b);rho=C(1,2);end
end
