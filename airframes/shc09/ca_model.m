function model = ca_model(cfg)
% 物理对象与分配器名义效能分开；分配器不读取实时真实气流和舵角。
if string(cfg.plant_model)=="hover_linear"
    model=ca_model_hover(cfg);
    model.plant_model="hover_linear";
    model.trim_delta_rad=zeros(6,1);
    model.hover_motor_rad_s=0;
    return;
end
p=ca_shc09_parameters();
model.parameters=p;
model.plant_model="shc09_6dof";
model.inertia=p.J; model.mass_kg=p.m;
model.coordinate_frame='b';
model.hinges_b=p.hinges_b;
model.hover_motor_rad_s=sqrt(p.m*p.g/p.Duct.k_T0);
model.hover_exit_speed_m_s=sqrt(p.m*p.g/(p.sd*p.den*p.S));
% 真实 b 系 B：列=真实舵面1-6；行=b1,b2,b3 力矩。
model.torque_matrix=p.d_cs*model.hover_exit_speed_m_s^2*p.arm_diag_b*p.P_cs_b;
model.acceleration_matrix=p.J_b\model.torque_matrix;
model.source_file='ICGNC_matlab2.0/SHC09_Sys.m';
model.source_limit_deg=40;
limit=cfg.command_limit_deg; if isempty(limit), limit=40; end
assert(isscalar(limit) && isfinite(limit) && limit>0 && limit<=40,'偏角限幅必须在0至40度之间。');
model.command_limit_deg=limit;
model.command_lower=-deg2rad(limit)*ones(6,1);
model.command_upper=-model.command_lower;
% 风扇反扭矩与固定片反扭矩并非恰好相等，静止悬停需要非零配平舵角。
residual=-p.FanDir*p.Duct.k_Q0*model.hover_motor_rad_s^2 ...
    +p.FanDir*p.k_sta*model.hover_exit_speed_m_s^2;
% b 系 yaw 是第 3 行（b3 为截面法向）；残余偏航力矩放在 b3。
model.trim_delta_rad=pinv(model.torque_matrix)*[0;0;-residual];
assert(all(abs(model.trim_delta_rad)<=model.command_upper),'当前舵角限制不能实现静止悬停配平。');
assert(rank(model.acceleration_matrix)==3,'六舵面效能矩阵必须行满秩。');
end
