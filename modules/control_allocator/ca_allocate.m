function [command,info] = ca_allocate(method,v_h,v_c,delta_hat,model,cfg,timing)
% 基线只接收总需求；两种PCA接收补偿和跟踪分量。
B = model.acceleration_matrix;
target = v_h+v_c;
started = tic;
switch string(method)
    case "DA_NS"
        [command,info] = ca_da_ns(target,B,model,cfg);
    case "WLS"
        [command,info] = ca_wls(target,B,delta_hat,model,cfg);
    case "DCA"
        [command,info] = ca_dca(target,delta_hat,model,cfg);
    case "PCA_STATIC"
        [command,info] = ca_pca_static(v_h,v_c,B,delta_hat,model,cfg,timing);
    case "PCA_PREDICTIVE"
        [command,info] = ca_pca_predictive(v_h,v_c,B,delta_hat,model,cfg,timing);
    otherwise
        error('ca:UnknownMethod','未知分配方法：%s',method);
end
info.solve_time_s = toc(started);
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
