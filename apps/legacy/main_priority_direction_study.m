function study = main_priority_direction_study(overrides)
% 长驻留二维机动与补偿方向变化的共同条件对比入口。
ca_setup();
if nargin<1, overrides=struct(); end
study=run_priority_direction_study(overrides);
end
