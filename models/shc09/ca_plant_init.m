function state = ca_plant_init(model,cfg)
% 默认从无风静止悬停配平点开始，真实状态只由物理对象持有。
state.position=zeros(3,1); state.velocity=zeros(3,1);
if nargin>=2, state.position=cfg.initial_position_ned_m(:); end
state.rotation=eye(3); state.omega=zeros(3,1);
state.delta=model.trim_delta_rad;
state.motor=model.hover_motor_rad_s;
end
