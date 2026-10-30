function motor = ca_motor_step(motor,command,tau,duration_s,model)
% 电机转速一阶响应，使用参考工程限幅；时间常数仍是仿真假设。
if model.plant_model=="hover_linear", return; end
p=model.parameters;
command=min(max(command,p.omega_m_min),p.omega_m_max);
motor=command+(motor-command)*exp(-duration_s/tau);
end
