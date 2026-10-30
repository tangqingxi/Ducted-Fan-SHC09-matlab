function model = ca_model_hover(cfg)
% 从原SHC09.m复制悬停气动力、惯量和六舵面几何，保留相同符号约定。
l1 = 0.267;
l2 = 0.066;
d = pi/3;
model.inertia = diag([0.0438,0.0436,0.005006]);
model.mass_kg = 2.1;
radius = 0.114;
exit_ratio = 0.7268;
density = 1.2041;
area = 0.00693;
lift_slope = 0.767;
exit_speed = sqrt(model.mass_kg*9.8/(exit_ratio*density*pi*radius^2));
effectiveness = lift_slope*0.5*density*exit_speed^2*area;
model.torque_matrix = [-l1,-l1*cos(d),l1*cos(d),l1,l1*cos(d),-l1*cos(d); ...
    0,l1*sin(d),l1*sin(d),0,-l1*sin(d),-l1*sin(d);l2,l2,l2,l2,l2,l2]*effectiveness;
model.acceleration_matrix = model.inertia\model.torque_matrix;
model.source_file = '../SHC09.m';
model.source_limit_deg = 40;
if isempty(cfg.command_limit_deg), limit = 40; else, limit = cfg.command_limit_deg; end
assert(isscalar(limit) && isfinite(limit) && limit>0 && limit<=40,'偏角限幅必须在0至40度之间。');
model.command_limit_deg = limit;
model.command_lower = -deg2rad(limit)*ones(6,1);
model.command_upper = -model.command_lower;
assert(rank(model.acceleration_matrix)==3,'SHC09六舵面效能矩阵必须行满秩。');
end
