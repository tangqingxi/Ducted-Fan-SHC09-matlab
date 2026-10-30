function [summary,details] = ca_priority_restore_shadow(results,frequency_hz)
% 在同一历史输入上试算最小命令变化恢复，不接入闭环也不改变原始分配结果。
if nargin<2, frequency_hz=25; end
cfg=results.config; model=results.model; log=results.logs.PCA_PREDICTIVE;
window=results.protocol.maneuver_window_s;
events=find(log.pwm_update_time_s>=window(1) & log.pwm_update_time_s<window(2));
events=events(1:max(1,round(cfg.pwm_hz/frequency_hz)):end);
options=optimoptions('lsqlin','Display','none','OptimalityTolerance',1e-10,'ConstraintTolerance',1e-10);
rows={};
for event=events'
    index=round(log.pwm_source_time_s(event)*cfg.sample_hz)+1;
    assert(abs(results.reference.time_s(index)-log.pwm_source_time_s(event))<1e-9,'PWM候选来源时钟错误。');
    command=log.pwm_command_rad(event,:)'; held=log.allocation_held_command_rad(index,:)';
    assert(norm(command-log.command_rad(index,:)',Inf)<1e-10,'下发命令与候选来源不一致。');
    timing=ca_pwm_timing(results.reference.time_s(index),cfg,held);
    at=ca_actuator_step(log.estimated_delta_rad(index,:)',held,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
    hold_s=timing.hold_s*cfg.predictive_horizon_fraction;
    g=1-exp(-hold_s./cfg.tau_model_s); M=model.acceleration_matrix*diag(g);
    lo=max(model.command_lower,at-cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    hi=min(model.command_upper,at+cfg.tau_model_s*deg2rad(cfg.rate_limit_deg_s));
    scale=vecnorm(M,2,2);
    [alternative,~,~,flag]=lsqlin(eye(6),held,[],[],M./scale,(M*command)./scale,lo,hi,[],options);
    assert(flag>0,'冻结输入的最小变化恢复未正常求解。');
    difference=norm(M*(alternative-command),Inf);
    assert(difference<1e-7 && all(alternative>=lo-1e-8 & alternative<=hi+1e-8),'恢复试算改变了预测虚拟控制或违反边界。');
    before=mean(rad2deg(command-held).^2); after=mean(rad2deg(alternative-held).^2);
    assert(after<=before+1e-6,'最小变化目标比原始可行命令更差。');
    rows(end+1,:)={log.pwm_update_time_s(event),before,after,difference,flag}; %#ok<AGROW>
end
details=cell2table(rows,'VariableNames',{'pwm_time_s','original_step_mean_square_deg2', ...
    'alternative_step_mean_square_deg2','predicted_effect_difference_rad_s2','exitflag'});
summary=table(string(results.scenario),height(details),sqrt(mean(details.original_step_mean_square_deg2)), ...
    sqrt(mean(details.alternative_step_mean_square_deg2)),max(details.predicted_effect_difference_rad_s2), ...
    'VariableNames',{'scenario','sampled_pwm_count','original_single_step_rms_deg', ...
    'shadow_single_step_rms_deg','max_predicted_effect_difference_rad_s2'});
end
