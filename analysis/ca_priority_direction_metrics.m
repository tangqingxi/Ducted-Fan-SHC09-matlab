function [metrics,terminals] = ca_priority_direction_metrics(results)
% 同时评价整段、机动瞬态和末端到达，避免只用角度指标评价位置任务。
cfg=results.config; ref=results.reference; t=ref.time_s; labels=string({results.variants.label});
names=["whole","loaded_hold","maneuver","command_transients","load_turn","return","recovery"];
legs=results.protocol.leg_windows_s; return_s=legs(end,2); unload_s=return_s+6;
transients=false(size(t)); turns=false(size(t));
for k=1:size(legs,1), transients=transients | (t>=legs(k,1) & t<legs(k,1)+0.75); end
for k=2:size(legs,1), turns=turns | (t>=legs(k,1)-2 & t<legs(k,1)-0.5); end
selections={t>=0 & t<cfg.duration_s,t>=3 & t<4,t>=4 & t<return_s, ...
    transients,turns,t>=return_s & t<unload_s,t>=unload_s+0.75 & t<cfg.duration_s};
rows={}; terminal_rows={};
for label=labels
    if ~isfield(results.logs,label), continue; end
    log=results.logs.(label);
    position=log.position_ned_m-ref.position_ned_m;
    yaw=rad2deg(atan2(sin(log.euler_rad(:,3)-ref.euler_rad(:,3)),cos(log.euler_rad(:,3)-ref.euler_rad(:,3))));
    rate=rad2deg(log.omega_rad_s-log.omega_reference_rad_s);
    for w=1:numel(names)
        selected=selections{w}; ticks=find(selected);
        events=interp1(t,double(selected),log.pwm_update_time_s,'previous',0)>0.5;
        commands=rad2deg(log.pwm_command_rad(events,:)); changes=diff(commands);
        normal=log.mode(selected)==0 & isfinite(log.lambda(selected));
        scaled=normal & log.lambda(selected)<1-1e-6;
        amount=sum(scaled)/cfg.sample_hz; percent=100*mean(scaled);
        if ~startsWith(label,"PCA"), amount=NaN; percent=NaN; end
        tau=cfg.tau_actual_s'; if isfield(log,'actual_tau_s'), tau=log.actual_tau_s(selected,:); end
        speed=abs((log.held_command_rad(selected,:)-log.actual_delta_rad(selected,:))./tau);
        rows(end+1,:)={char(results.scenario),char(label),char(names(w)),sqrt(mean(yaw(selected).^2)), ...
            max(abs(yaw(selected))),sqrt(mean(sum(position(selected,:).^2,2))), ...
            sqrt(mean(sum(rate(selected,:).^2,2))),sqrt(mean(sum(rad2deg(log.euler_error_rad(selected,1:2)).^2,2))), ...
            100*mean(any(abs(commands)>=results.model.command_limit_deg-1e-5,2)), ...
            sqrt(mean(changes.^2,'all')),amount,percent, ...
            100*mean(log.mode(selected)==1),100*mean(log.mode(selected)==2), ...
            sum(log.solver_exitflag(selected)<=0),sum(log.solver_rescue(selected)), ...
            100*mean(log.table_extrapolated(selected)),100*mean(any(speed>=deg2rad(cfg.rate_limit_deg_s)-1e-8,2))}; %#ok<AGROW>
    end
    for k=1:size(results.protocol.leg_windows_s,1)
        window=results.protocol.leg_windows_s(k,:);
        selected=t>=window(1) & t<window(2);
        ending=t>=window(2)-0.5 & t<window(2);
        error=vecnorm(position,2,2); speed=vecnorm(log.velocity_ned_m_s,2,2);
        acceptable=error<results.protocol.settling_radius_m & speed<results.protocol.settling_speed_m_s;
        ids=find(selected); hold_count=round(results.protocol.settling_hold_s*cfg.sample_hz);
        streak=conv(double(acceptable(ids)),ones(hold_count,1),'valid');
        first=find(streak>=hold_count,1); settling=NaN;
        if ~isempty(first), settling=t(ids(first))-window(1); end
        terminal_rows(end+1,:)={char(results.scenario),char(label),k,window(1),window(2), ...
            sqrt(mean(error(ending).^2)),max(error(ending)),max(speed(ending)), ...
            all(acceptable(ending)),settling}; %#ok<AGROW>
    end
end
metrics=cell2table(rows,'VariableNames',{'scenario','variant','window','yaw_rmse_deg','yaw_peak_deg','position_rmse_m', ...
    'rate_control_rmse_deg_s','tilt_error_rmse_deg','pwm_saturation_percent','command_step_rms_deg', ...
    'normal_scaled_s','normal_scaled_percent','mode1_percent','mode2_percent','solver_nonoptimal_count', ...
    'solver_rescue_count','aero_extrapolated_percent','rate_limited_percent'});
terminals=cell2table(terminal_rows,'VariableNames',{'scenario','variant','leg','start_s','end_s','terminal_position_rmse_m', ...
    'terminal_position_peak_m','terminal_speed_peak_m_s','terminal_success','first_settling_time_s'});
end
