function metrics = ca_metrics(results)
% 按共同时间窗评价真实刚体误差、约束、指令变化和分配计算代价。
cfg=results.config;
ref=results.reference;
windows=[min(2,cfg.duration_s/4),cfg.duration_s-min(1,cfg.duration_s/10);3,7;9,13;15,19;21,25;27,28];
labels=["effective","low","medium","fast","high","recovery"];
rows={};
for window=1:size(windows,1)
    limits=windows(window,:);
    if limits(2)>cfg.duration_s || limits(2)<=limits(1), continue; end
    selected=ref.time_s>=limits(1) & ref.time_s<=limits(2);
    for method=cfg.methods
        log=results.logs.(method);
        error=rad2deg(log.euler_error_rad(selected,:));
        attitude=rad2deg(log.rotation_error_rad(selected));
        rate=rad2deg(log.rate_error_rad_s(selected,:));
        events=log.pwm_update_time_s>=limits(1) & log.pwm_update_time_s<=limits(2);
        commands=rad2deg(log.pwm_command_rad(events,:));
        changes=diff(commands);
        if isempty(changes), change_rms=NaN; change_max=NaN;
        else, change_rms=sqrt(mean(changes.^2,'all')); change_max=max(abs(changes),[],'all'); end
        saturated=any(abs(commands)>=results.model.command_limit_deg-1e-5,2);
        tau=cfg.tau_actual_s'; if isfield(log,'actual_tau_s'), tau=log.actual_tau_s(selected,:); end
        speed=abs((log.held_command_rad(selected,:)-log.actual_delta_rad(selected,:))./tau);
        limited=any(speed>=deg2rad(cfg.rate_limit_deg_s)-1e-8,2);
        checked=events & log.pwm_prediction_checked;
        forecast=rad2deg(log.pwm_end_prediction_error_rad(checked,:));
        if isempty(forecast), forecast_max=NaN; else, forecast_max=max(abs(forecast),[],'all'); end
        rows(end+1,:)={char(method),char(labels(window)),sqrt(mean(error(:,1).^2)), ...
            sqrt(mean(error(:,2).^2)),sqrt(mean(error(:,3).^2)),sqrt(mean(attitude.^2)), ...
            max(attitude),sqrt(mean(sum(rate.^2,2))),max(abs(commands),[],'all'), ...
            100*mean(saturated),100*mean(limited),change_rms,change_max, ...
            mean(log.solve_time_s(selected))*1000,max(log.solve_time_s(selected))*1000, ...
            sum(log.solver_exitflag(selected)<=0),sum(log.mode(selected)>0), ...
            sum(log.solver_rescue(selected)),mean(log.iterations(selected)), ...
            mean(log.common_residual(selected)),mean(log.priority_distance(selected)),forecast_max}; %#ok<AGROW>
    end
end
metrics=cell2table(rows,'VariableNames',{'method','stage','roll_rmse_deg','pitch_rmse_deg','yaw_rmse_deg', ...
    'rotation_rmse_deg','rotation_peak_deg','rate_rmse_deg_s','max_pwm_command_deg', ...
    'position_saturation_percent','rate_limit_percent','command_step_rms_deg','command_step_max_deg', ...
    'solve_mean_ms','solve_max_ms','solver_nonoptimal_count','fallback_count','solver_rescue_count', ...
    'iterations_mean','common_residual_mean','priority_distance_mean','common_prediction_error_max_deg'});
end
