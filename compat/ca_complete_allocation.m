function info = ca_complete_allocation(info,command,v_h,v_c,delta_hat,model,cfg,timing)
% 旧日志字段和公共预测的兼容计算；不决定插件类型。
B=model.acceleration_matrix;target=v_h+v_c;
defaults = struct('lambda',NaN,'beta',NaN,'mode',0,'solver_rescue',false, ...
    'iterations',NaN,'exitflag',1,'equality_error',NaN,'native_predicted_delta',NaN(6,1), ...
    'native_horizon_s',NaN,'native_prediction_available',false, ...
    'restore_exitflag',NaN,'restore_iterations',0,'restore_effect_error',NaN,'restore_solver_rescue',false);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(info,fields{k}), info.(fields{k}) = defaults.(fields{k}); end
end
assert(all(isfinite(command)) && all(command>=model.command_lower-1e-7) ...
    && all(command<=model.command_upper+1e-7),'算法返回非有限或超限指令。');
% 所有方法在同一评价时刻做独立后处理，静态方法不宣称原生预测能力。
rate = deg2rad(cfg.rate_limit_deg_s);
at_delivery = ca_actuator_step(delta_hat,timing.held_command,cfg.tau_model_s,timing.delay_s,rate);
info.predicted_delta = ca_actuator_step(at_delivery,command,cfg.tau_model_s,timing.hold_s,rate);
info.common_residual = norm(B*info.predicted_delta-target);
info.native_residual = norm(info.allocated_effect-target);
if norm(v_c)>1e-12
    ratio = min(1,max(0,v_c'*(B*info.predicted_delta-v_h)/(v_c'*v_c)));
else
    ratio = 0;
end
info.priority_distance = norm(B*info.predicted_delta-v_h-ratio*v_c);
info.prediction_delay_s = timing.delay_s;
info.prediction_horizon_s = timing.horizon_s;
end
