function [command, info] = ca_priority_core(v_h, v_c, B, delta_hat, model, cfg, predictive, timing)
% 来源：code/shc09_predictive_allocator.m；独立副本，原文件未修改。
% 复用原有优先级线性规划，新增预测偏置、动态约束和显式降级处理。
persistent lp_options
if isempty(lp_options)
    lp_options = optimoptions('linprog', 'Display', 'none');
end
if nargin < 8
    timing = ca_pwm_timing(0,cfg,zeros(size(delta_hat)));
end
lower = model.command_lower;
upper = model.command_upper;
rate = deg2rad(cfg.rate_limit_deg_s);
tau = cfg.tau_model_s(:);
at_delivery = ca_actuator_step(delta_hat,timing.held_command,tau,timing.delay_s,rate);
if predictive
    f = exp(-timing.hold_s./tau);
    g = 1-f;
    matrix = B*diag(g);
    continued = B*(f.*at_delivery);
    % 限制新目标的初始追赶速度，使整个保持段不触发速率饱和，仿射预测才严格成立。
    % 这是保守的指令约束；真实舵机和估计器仍允许按完整限速一阶模型运动。
    lower = max(lower, at_delivery-tau*rate);
    upper = min(upper, at_delivery+tau*rate);
else
    matrix = B;
    continued = zeros(3,1);
end
info.mode = 0;
info.lambda = 1;
info.solver_rescue = false;
[command, ok, lambda, rescued, iterations] = solve_ray(v_h-continued, v_c, matrix, lower, upper, cfg, lp_options);
info.iterations = iterations;
info.solver_rescue = rescued;
if ~ok
    % 回退时只缩放高优先级目标，不缩放当前偏角延续产生的控制效果。
    info.mode = 1;
    [command, ok, lambda, rescued, iterations] = solve_ray(-continued, v_h, matrix, lower, upper, cfg, lp_options);
    info.iterations = info.iterations+iterations;
    info.solver_rescue = info.solver_rescue || rescued;
end
if ~ok
    % 动态可达集合可能不含零；两条优先级射线均不可达时，仅最小化高优先级残差。
    info.mode = 2;
    target = v_h-continued;
    inequality = [matrix, -ones(3,1); -matrix, -ones(3,1)];
    bound = [target; -target];
    [solution, ~, exitflag, output] = linprog([zeros(6,1);1], inequality, bound, ...
        [], [], [lower;0], [upper;Inf], lp_options);
    if exitflag <= 0
        error('shc09:EmergencyAllocationFailed', '最小高优先级残差问题未能求解，不能把错误结果继续用于仿真。');
    end
    command = solution(1:6);
    info.iterations = info.iterations+output.iterations;
    lambda = NaN;
end
before_restore = matrix*command;
info.restore_exitflag=NaN;
info.restore_iterations=0;
info.restore_solver_rescue=false;
if predictive && isfield(cfg,'predictive_restore_mode') && string(cfg.predictive_restore_mode)=="minimum_change"
    [command,restored]=ca_restore_minimum_change(matrix,command,timing.held_command,lower,upper);
    info.restore_exitflag=restored.exitflag;
    info.restore_iterations=restored.iterations;
    info.restore_solver_rescue=restored.solver_rescue;
else
    command = ca_restore(matrix, command, lower, upper);
end
info.restore_effect_error=norm(matrix*command-before_restore,Inf);
assert(norm(matrix*command-before_restore, Inf) < 1e-5, '恢复操作改变了已分配的控制效果。');
assert(all(command >= lower-1e-7 & command <= upper+1e-7), '分配指令超出约束。');
info.lambda = lambda;
info.allocated_effect = continued+matrix*command;
info.predicted_delta = ca_actuator_step(at_delivery,command,tau,timing.hold_s,rate);
info.predicted_effect = B*info.predicted_delta;
info.delivery_delta = at_delivery;
info.prediction_delay_s = timing.delay_s;
info.prediction_horizon_s = timing.horizon_s;
info.trim_error = norm(info.allocated_effect-v_h);
if predictive
    assert(norm(info.predicted_effect-info.allocated_effect,Inf) < 1e-7, '保持段实际模型与仿射预测不一致。');
end
if info.mode == 0
    info.equality_error = norm(info.allocated_effect-v_h-lambda*v_c, Inf);
elseif info.mode == 1
    info.equality_error = norm(info.allocated_effect-lambda*v_h, Inf);
else
    info.equality_error = NaN;
end
end

function [command, ok, lambda, rescued, iterations] = solve_ray(offset, direction, matrix, lower, upper, cfg, lp_options)
% 对原求解器结果检查残差；零方向和异常退出使用同一个线性规划复核。
rescued = false;
iterations = 0;
command = zeros(size(lower));
lambda = 0;
ok = false;
if norm(direction, Inf) > 1e-12
    captured = evalc('[command, status, lambda, iterations] = ca_dp_lpca(offset, direction, matrix, lower, upper, cfg.max_iterations);'); %#ok<NASGU>
    ok = status == 0 && valid_solution(command, lambda, offset, direction, matrix, lower, upper, cfg);
end
if ~ok
    % 用第二个求解器区分真实不可达与原函数的零方向或数值异常。
    [solution, ~, exitflag, output] = linprog([zeros(numel(lower),1);-1], [], [], ...
        [matrix,-direction], offset, [lower;0], [upper;1], lp_options);
    iterations = iterations+output.iterations;
    if exitflag > 0
        command = solution(1:end-1);
        lambda = solution(end);
        ok = valid_solution(command, lambda, offset, direction, matrix, lower, upper, cfg);
        rescued = true;
    end
end
end

function ok = valid_solution(command, lambda, offset, direction, matrix, lower, upper, cfg)
ok = all(isfinite(command)) && isfinite(lambda) && lambda >= -1e-7 && lambda <= 1+1e-7 ...
    && all(command >= lower-1e-7 & command <= upper+1e-7) ...
    && norm(matrix*command-offset-lambda*direction, Inf) <= cfg.constraint_tolerance;
end
