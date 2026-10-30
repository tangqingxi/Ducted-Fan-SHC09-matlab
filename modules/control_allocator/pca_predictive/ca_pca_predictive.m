function [command,info] = ca_pca_predictive(v_h,v_c,B,delta_hat,model,cfg,timing)
% 等待旧指令阶段加指定保持周期比例；真实PWM仍保持完整周期。
fraction=1;
if isfield(cfg,'predictive_horizon_fraction'), fraction=cfg.predictive_horizon_fraction; end
timing.hold_s=timing.hold_s*fraction;
timing.horizon_s=timing.delay_s+timing.hold_s;
[command,info] = ca_priority_core(v_h,v_c,B,delta_hat,model,cfg,true,timing);
info.beta = NaN;
if info.mode==1, info.beta=info.lambda; info.lambda=NaN; end
info.native_predicted_delta = info.predicted_delta;
info.native_horizon_s = timing.horizon_s;
info.native_prediction_available = true;
end
