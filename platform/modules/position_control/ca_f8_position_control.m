function [rotation,motor,omega,alpha] = ca_f8_position_control(position,velocity,reference,model,cfg)
% F8专用前馈分支：借鉴PX4叠加速度和加速度参考，旧位置控制函数保持原样。
required=["position","velocity","acceleration","yaw","rotation_ff","omega_ff","alpha_ff"];
for field=required,assert(isfield(reference,field),'F8前馈参考缺少字段%s。',field);end
assert(all(isfinite([position(:);velocity(:);reference.position(:);reference.velocity(:);reference.acceleration(:); ...
    reference.yaw;reference.rotation_ff(:);reference.omega_ff(:);reference.alpha_ff(:)])),'F8参考或估计存在非有限数。');
a=reference.acceleration(:)+cfg.position_gain(:).*(reference.position(:)-position(:)) ...
    +cfg.velocity_gain(:).*(reference.velocity(:)-velocity(:));
horizontal=norm(a(1:2));if horizontal>4,a(1:2)=a(1:2)*(4/horizontal);end
a(3)=min(4,max(-4,a(3)));p=model.parameters;
maximum=cfg.f8_max_thrust_fraction*p.Duct.k_T0*p.omega_m_max^2;
% 在总推力与倾角限制内优先保留竖直分量；没有积分器，不引入积分饱和处理。
up=min(maximum,max(1e-6,model.mass_kg*(p.g-a(3))));xy=model.mass_kg*a(1:2);
xy_limit=min(up*tan(deg2rad(cfg.f8_max_tilt_deg)),sqrt(max(0,maximum^2-up^2)));
if norm(xy)>xy_limit,xy=xy*(xy_limit/norm(xy));end
force=[xy;-up];b3=-force/norm(force);yaw=reference.yaw;
rotated=[cos(yaw),sin(yaw),0;-sin(yaw),cos(yaw),0;0,0,1]*b3;
rotation=ca_euler_rotation([asin(min(1,max(-1,-rotated(2))));atan2(rotated(1),rotated(3));yaw]);
motor=sqrt(norm(force)/p.Duct.k_T0);motor=min(max(motor,p.omega_m_min),p.omega_m_max);
% 名义几何前馈转到反馈修正后的期望机体系；不对估计噪声求导，也不声称是反馈姿态的精确导数。
transport=rotation'*reference.rotation_ff;omega=transport*reference.omega_ff(:);alpha=transport*reference.alpha_ff(:);
end
