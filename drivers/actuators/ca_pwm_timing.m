function timing = ca_pwm_timing(time_s, cfg, held_command)
% 来源：code/shc09_pwm_timing.m；独立副本，原文件未修改。
% 返回不早于当前时刻的PWM刷新点；对齐时先算控制器，再下发新指令。
period = 1/cfg.pwm_hz;
relative_tick = (time_s-cfg.pwm_phase_s)/period;
tick_tolerance = 64*eps(max(1,abs(relative_tick)));
tick = max(0,ceil(relative_tick-tick_tolerance));
delivery_time = cfg.pwm_phase_s+tick*period;
timing.delivery_time_s = delivery_time;
timing.delay_s = max(0,delivery_time-time_s);
timing.hold_s = period;
timing.horizon_s = timing.delay_s+period;
timing.held_command = held_command(:);
end
