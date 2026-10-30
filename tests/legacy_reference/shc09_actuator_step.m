function next = shc09_actuator_step(current, command, tau, duration_s, rate_limit_rad_s)
% 精确推进目标保持不变的一阶舵机；有速率限制时先匀速，再接指数响应。
% 该连续模型的分段推进与整段推进一致，适合跨越非整数倍PWM事件。
assert(duration_s >= 0 && isfinite(duration_s), '推进时长必须为非负有限数。');
assert(rate_limit_rad_s > 0 && all(tau(:) > 0), '速率上限和时间常数必须为正。');
current = current(:);
command = command(:);
if isscalar(tau), tau = repmat(tau,numel(current),1); else, tau = tau(:); end
assert(numel(current)==numel(command) && numel(tau)==numel(current), '舵机状态、目标和时间常数维度必须一致。');
if duration_s == 0
    next = current;
    return;
end
error = command-current;
distance = abs(error);
direction = sign(error);
if isinf(rate_limit_rad_s)
    next = command-error.*exp(-duration_s./tau);
    return;
end
switch_distance = tau*rate_limit_rad_s;
saturated_time = max(0,(distance-switch_distance)/rate_limit_rad_s);
linear_time = min(duration_s,saturated_time);
remaining_time = max(0,duration_s-saturated_time);
remaining_distance = distance-rate_limit_rad_s*linear_time;
next = command-direction.*remaining_distance.*exp(-remaining_time./tau);
end
