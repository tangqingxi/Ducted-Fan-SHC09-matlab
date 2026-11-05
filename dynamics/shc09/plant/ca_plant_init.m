function state = ca_plant_init(model,cfg)
% 默认从无风静止悬停配平点开始，真实状态只由物理对象持有。
state.position=zeros(3,1); state.velocity=zeros(3,1);
if nargin>=2, state.position=cfg.initial_position_ned_m(:); end
if isfield(model,'parameters') && isfield(model.parameters,'R_old_to_b')
    % 初始物理姿态在旧原生系为单位阵；换到 b 系后为 R'（b= R*old）。
    state.rotation=model.parameters.R_old_to_b';
else
    state.rotation=eye(3);
end
state.omega=zeros(3,1);
state.delta=model.trim_delta_rad;
state.motor=model.hover_motor_rad_s;
end
