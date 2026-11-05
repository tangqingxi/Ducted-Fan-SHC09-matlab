function nominal = shc09_nominal_effectiveness(model,cfg)
% 只提取固定名义几何和力矩度量，绝不传递parameters或实时真实舵效。
names=["plant_model","acceleration_matrix","torque_matrix","inertia", ...
 "command_lower","command_upper","trim_delta_rad"];
nominal=struct();for name=names,nominal.(name)=model.(name);end
nominal.B=model.acceleration_matrix;nominal.tau_model_s=cfg.tau_model_s;
end
