function [demand,motor,mem,s]=ppid_control_step(fb,r,nominal,p,measurement,mem,tick)
% 控制接口只接收估计反馈、轨迹、名义常量和滤波历史，不接受真实状态或完整仿真配置。
dt=1/400;
if isempty(mem)
    mem=struct('integral',zeros(3,1),'previous_velocity',fb.velocity,'derivative',zeros(3,1), ...
        'velocity_sp',zeros(3,1),'acceleration_sp',zeros(3,1),'rotation_sp',eye(3), ...
        'omega_sp',zeros(3,1),'motor',sqrt(nominal.mass*nominal.gravity/nominal.thrust_k), ...
        'position_updates',0,'velocity_updates',0,'attitude_updates',0,'rate_updates',0);
end
if mod(tick,16)==0
    mem.velocity_sp=r.velocity+p.position_gain(:).*(r.position-fb.position);
    mem.velocity_sp=min(p.velocity_limit_m_s,max(-p.velocity_limit_m_s,mem.velocity_sp));
    mem.position_updates=mem.position_updates+1;
end
if mod(tick,8)==0
    period=8*dt;error=mem.velocity_sp-fb.velocity;
    fraction=-expm1(-2*pi*p.velocity_derivative_cutoff_hz*period);
    mem.derivative=mem.derivative+fraction*((fb.velocity-mem.previous_velocity)/period-mem.derivative);
    mem.previous_velocity=fb.velocity;
    trial=min(p.velocity_integral_limit,max(-p.velocity_integral_limit,mem.integral+period*error));
    candidate=r.acceleration+p.velocity_p(:).*error+p.velocity_i(:).*trial-p.velocity_d(:).*mem.derivative;
    limited=candidate;horizontal=norm(limited(1:2));
    if horizontal>p.acceleration_limit_m_s2,limited(1:2)=limited(1:2)*p.acceleration_limit_m_s2/horizontal;end
    limited(3)=min(p.acceleration_limit_m_s2,max(-p.acceleration_limit_m_s2,limited(3)));
    % 输出限幅时冻结本次积分，五种分配器共用相同规则。
    if norm(candidate-limited)<1e-10,mem.integral=trial;end
    mem.acceleration_sp=limited;
    maximum=p.thrust_fraction_limit*nominal.thrust_k*nominal.omega_max^2;
    up=min(maximum,max(1e-6,nominal.mass*(nominal.gravity-limited(3))));
    xy=nominal.mass*limited(1:2);cap=min(up*tan(deg2rad(p.tilt_limit_deg)),sqrt(max(0,maximum^2-up^2)));
    if norm(xy)>cap,xy=xy*cap/norm(xy);end
    force=[xy;-up];b3=-force/norm(force);yaw=r.yaw;
    v=[cos(yaw),sin(yaw),0;-sin(yaw),cos(yaw),0;0,0,1]*b3;
    mem.rotation_sp=ca_euler_rotation([asin(min(1,max(-1,-v(2))));atan2(v(1),v(3));yaw]);
    mem.motor=min(nominal.omega_max,max(nominal.omega_min,sqrt(norm(force)/nominal.thrust_k)));
    mem.velocity_updates=mem.velocity_updates+1;
end
transport=fb.rotation'*r.rotation_ff;omega_ff=transport*r.omega_ff;
if mod(tick,4)==0
    relative=fb.rotation'*mem.rotation_sp;
    error=quaternion_error(relative);
    mem.omega_sp=omega_ff+p.attitude_gain(:).*error;
    mem.attitude_updates=mem.attitude_updates+1;
end
% 只对计划参考做坐标运输，不求姿态反馈误差的导数并混作前馈。
gamma_ff=transport*r.gamma_ff-cross(fb.omega,omega_ff);
gamma_sp=gamma_ff+p.rate_gain(:).*(mem.omega_sp-fb.omega);
vh=nominal.B*measurement.delta_feedback-measurement.alpha;
demand=struct('v_h',vh,'v_c',gamma_sp);motor=mem.motor;
mem.rate_updates=mem.rate_updates+1;
s=struct('velocity_sp',mem.velocity_sp,'acceleration_sp',mem.acceleration_sp, ...
    'rotation_sp',mem.rotation_sp,'omega_sp',mem.omega_sp,'gamma_sp',gamma_sp,'gamma_ff',gamma_ff);
end

function error=quaternion_error(R)
% 从同一相对旋转构造规范化四元数误差；避免大角度时正弦误差退化。
K=[R(1,1)-R(2,2)-R(3,3),R(1,2)+R(2,1),R(1,3)+R(3,1),R(3,2)-R(2,3); ...
    R(1,2)+R(2,1),R(2,2)-R(1,1)-R(3,3),R(2,3)+R(3,2),R(1,3)-R(3,1); ...
    R(1,3)+R(3,1),R(2,3)+R(3,2),R(3,3)-R(1,1)-R(2,2),R(2,1)-R(1,2); ...
    R(3,2)-R(2,3),R(1,3)-R(3,1),R(2,1)-R(1,2),trace(R)]/3;
[V,D]=eig(K);[~,i]=max(diag(D));q=V(:,i);q=[q(4);q(1:3)];
first=find(abs(q)>1e-12,1);q=q*sign(q(first));error=2*q(2:4);
end
