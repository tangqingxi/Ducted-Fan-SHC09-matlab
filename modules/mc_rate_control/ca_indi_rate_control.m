function [v_h,v_c] = ca_indi_rate_control(omega,alpha,feedback_delta,omega_reference,alpha_reference,model,cfg)
% 补偿使用滤波历史舵角；分配器动态预测另用当前模型舵角。
v_h=model.acceleration_matrix*feedback_delta-alpha+alpha_reference;
v_c=cfg.rate_gain(:).*(omega_reference-omega);
end
