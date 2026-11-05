function [stop,high_speed_gate,airspeed] = ca_mismatch_should_stop(problem,cfg,fail_fast)
% 除快速失败选项外，仅真实气动适用域失败要求整体停止；未知空速保守停止。
airspeed=NaN; high_speed_gate=false;
if strcmp(problem.identifier,'ca:AeroTableDomain')
    token=regexp(problem.message,'空速=([0-9eE+.-]+)米每秒','tokens','once');
    if ~isempty(token), airspeed=str2double(token{1}); end
    high_speed_gate=~isfinite(airspeed) || airspeed>cfg.aero_low_speed_m_s;
end
stop=logical(fail_fast) || high_speed_gate;
end
