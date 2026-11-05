function [rotation,motor] = ca_position_control(position,velocity,yaw,model,cfg,position_reference)
% 可选公共位置外环；当前位置和速度假定由理想导航估计给出，尚未建立导航误差模型。
assert(model.plant_model=="shc09_6dof",'位置控制需要六自由度模型。');
p=model.parameters;
if nargin<6, position_reference=cfg.position_reference_ned_m; end
acceleration=cfg.position_gain(:).*(position_reference(:)-position)-cfg.velocity_gain(:).*velocity;
% 限制外环倾斜和加速度，避免把悬停基准变成大范围过渡飞行。
horizontal=norm(acceleration(1:2));
if horizontal>4, acceleration(1:2)=acceleration(1:2)*(4/horizontal); end
acceleration(3)=min(4,max(-4,acceleration(3)));
force=model.mass_kg*(acceleration-[0;0;p.g]);
b3=-force/norm(force);
mode="legacy_projection";
if isfield(cfg,'position_attitude_mode'), mode=string(cfg.position_attitude_mode); end
if mode=="exact_yaw"
    % 在给定偏航坐标中解析求滚转和俯仰，同时精确满足推力方向和偏航角。
    rotated=[cos(yaw),sin(yaw),0;-sin(yaw),cos(yaw),0;0,0,1]*b3;
    roll=asin(min(1,max(-1,-rotated(2))));
    pitch=atan2(rotated(1),rotated(3));
    rotation=ca_euler_rotation([roll;pitch;yaw]);
else
    % 保留旧投影构造以复核历史结果，旧配置缺少模式字段时也走此分支。
    heading=[cos(yaw);sin(yaw);0];
    b2=cross(b3,heading); b2=b2/norm(b2); b1=cross(b2,b3);
    rotation=[b1,b2,b3];
end
motor=sqrt(norm(force)/p.Duct.k_T0);
motor=min(max(motor,p.omega_m_min),p.omega_m_max);
end
