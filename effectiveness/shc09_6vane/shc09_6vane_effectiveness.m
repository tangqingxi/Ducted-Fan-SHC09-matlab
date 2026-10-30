function nominal = shc09_6vane_effectiveness(model,cfg)
% 保留原名义矩阵的字节，不从真实气流或舵效重新辨识。
nominal=shc09_nominal_effectiveness(model,cfg);
end
