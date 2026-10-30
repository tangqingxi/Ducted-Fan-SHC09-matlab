function [command,info] = ca_dca(target,delta_hat,model,cfg)
% DCA单步数值适配：以受限模型的实际终点力矩误差为目标，不计等待旧指令阶段。
% 一阶限速响应对指令连续单调，先在精确可达终点区间求解，再反解目标指令。
persistent options
if isempty(options)
    options=optimoptions('lsqlin','Display','none','OptimalityTolerance',1e-10);
end
if isempty(cfg.dca_horizon_s), horizon=1/cfg.pwm_hz; else, horizon=cfg.dca_horizon_s; end
rate=deg2rad(cfg.rate_limit_deg_s);
lower=ca_actuator_step(delta_hat,model.command_lower,cfg.tau_model_s,horizon,rate);
upper=ca_actuator_step(delta_hat,model.command_upper,cfg.tau_model_s,horizon,rate);
C=model.torque_matrix;
desired=model.inertia*target;
% 同乘一个标量改善数值尺度，不改变三轴物理力矩的相对权重。
normalizer=norm(C,'fro');
[endpoint,~,~,flag,output] = lsqlin(C/normalizer,desired/normalizer,[],[],[],[], ...
    lower,upper,[],options);
assert(flag>0,'DCA终点误差优化失败。');
lo=model.command_lower;
hi=model.command_upper;
for k=1:48
    middle=(lo+hi)/2;
    response=ca_actuator_step(delta_hat,middle,cfg.tau_model_s,horizon,rate);
    smaller=response<endpoint;
    lo(smaller)=middle(smaller);
    hi(~smaller)=middle(~smaller);
end
command=(lo+hi)/2;
predicted=ca_actuator_step(delta_hat,command,cfg.tau_model_s,horizon,rate);
assert(norm(predicted-endpoint,Inf)<1e-8,'DCA反解指令未达到求解终点。');
info=struct('allocated_effect',model.acceleration_matrix*predicted, ...
    'native_predicted_delta',predicted,'native_horizon_s',horizon, ...
    'native_prediction_available',true,'iterations',output.iterations, ...
    'exitflag',flag,'mode',0,'objective_torque_error',norm(C*predicted-desired));
end
