function [metrics,checks]=f8_evaluate_run(L,cfg,model,ref,protocol)
% F8独立门禁：数据有效、飞行包线、任务跟踪和优先级激励分开，不调用悬停可比性函数。
t=ref.time_s;q=t>=protocol.motion_window_s(1)&t<=protocol.motion_window_s(2);dt=1/cfg.sample_hz;
position=L.position_ned_m-ref.position_ned_m;velocity=L.velocity_ned_m_s-ref.velocity_ned_m_s;
yaw=atan2(sin(L.euler_rad(:,3)-ref.euler_rad(:,3)),cos(L.euler_rad(:,3)-ref.euler_rad(:,3)));
horizontal=vecnorm(position(q,1:2),2,2);altitude=position(q,3);
metrics=struct('method',string(L.name),'seed',protocol.seed,'scenario_id',string(protocol.scenario.id), ...
    'horizontal_position_rmse_m',sqrt(mean(horizontal.^2)),'horizontal_position_peak_m',max(horizontal), ...
    'altitude_rmse_m',sqrt(mean(altitude.^2)),'altitude_peak_m',max(abs(altitude)), ...
    'velocity_rmse_m_s',sqrt(mean(sum(velocity(q,:).^2,2))), ...
    'yaw_rmse_deg',rad2deg(sqrt(mean(yaw(q).^2))),'yaw_peak_deg',rad2deg(max(abs(yaw(q)))), ...
    'inner_attitude_rmse_deg',rad2deg(sqrt(mean(L.rotation_error_rad(q).^2))), ...
    'inner_attitude_peak_deg',rad2deg(max(L.rotation_error_rad(q))), ...
    'estimator_attitude_rmse_deg',rad2deg(sqrt(mean(L.estimated_attitude_error_rad(q).^2))));
tilt=acos(min(1,max(-1,cos(L.euler_rad(:,1)).*cos(L.euler_rad(:,2)))));
metrics.max_actual_tilt_deg=rad2deg(max(tilt));metrics.max_command_deg=max(abs(rad2deg(L.command_rad)),[],'all');
metrics.max_actual_servo_deg=max(abs(rad2deg(L.actual_delta_rad)),[],'all');
metrics.max_actual_servo_rate_deg_s=max(abs(rad2deg(diff(L.actual_delta_rad,1,1)/dt)),[],'all');
metrics.max_motor_command_static_thrust_fraction=max((L.motor_command_rad_s/model.parameters.omega_m_max).^2);
metrics.command_limit_occupancy_percent=100*mean(any(abs(rad2deg(L.command_rad(q,:)))>=40-1e-5,2));
metrics.aero_extrapolation_count=sum(L.table_extrapolated);
finite=all(isfinite([L.position_ned_m,L.velocity_ned_m_s,L.euler_rad,L.omega_rad_s,L.command_rad, ...
    L.actual_delta_rad,L.motor_command_rad_s,L.rotation_error_rad,L.estimated_attitude_error_rad]),'all');
metrics.total_scaled_duration_s=NaN;metrics.longest_scaled_episode_s=NaN;metrics.lambda_min=NaN;
metrics.pca_high_priority_fallback_count=NaN;metrics.pca_engineering_fallback_count=NaN;
excited=false;
if startsWith(string(L.name),"PCA")
    scaled=L.mode(q)==0&isfinite(L.lambda(q))&L.lambda(q)<1-protocol.priority_evidence.lambda_tolerance;
    edges=diff([false;scaled(:);false]);lengths=find(edges==-1)-find(edges==1);
    metrics.total_scaled_duration_s=sum(scaled)*dt;
    metrics.longest_scaled_episode_s=max([0;lengths])*dt;metrics.lambda_min=min(L.lambda(q),[],'omitnan');
    metrics.pca_high_priority_fallback_count=sum(L.mode(q)==1);metrics.pca_engineering_fallback_count=sum(L.mode(q)==2);
    excited=metrics.total_scaled_duration_s>=protocol.priority_evidence.minimum_total_scaled_duration_s ...
        &&metrics.longest_scaled_episode_s>=protocol.priority_evidence.minimum_longest_scaled_episode_s;
end
valid=finite&&metrics.aero_extrapolation_count==0;
envelope=true;names=fieldnames(protocol.envelope);
for k=1:numel(names)
    name=names{k};if strcmp(name,'role'),continue;end
    envelope=envelope&&metrics.(name)<=protocol.envelope.(name)+1e-7;
end
tracking=true;names=fieldnames(protocol.tracking_requirements);
for k=1:numel(names)
    name=names{k};if strcmp(name,'role'),continue;end
    tracking=tracking&&metrics.(name)<=protocol.tracking_requirements.(name);
end
checks=struct('valid_data',valid,'flight_envelope_passed',envelope,'tracking_requirements_passed',tracking, ...
    'run_task_passed',valid&&envelope&&tracking,'priority_duration_excited',excited, ...
    'priority_geometry_audited',false,'priority_mechanism_claim_allowed',false, ...
    'role',"优先级结论另需独立几何审计及至少两个种子；单次时长通过不等于机制证明");
end
