function out = ca_shc09_aerodynamics(rotation,velocity,omega,delta,motor,model,cfg)
% 按参考工程移植气动力与力矩，保留其机体前向为y的坐标约定。
p=model.parameters;
air=rotation'*(velocity-cfg.wind_ned_m_s(:));
u=air(1); v=air(2); w=air(3);
motor=min(max(motor,p.omega_m_min),p.omega_m_max);
delta=min(max(delta,-p.cm),p.cm);
V=norm(air); Vuv=hypot(u,v); Vvw=hypot(v,w);
low_speed=false;
regularized_model=false; V_low=1;
if isfield(cfg,'aero_low_speed_model') && string(cfg.aero_low_speed_model)=="hold_90"
    regularized_model=true;
    if isfield(cfg,'aero_low_speed_m_s'), V_low=cfg.aero_low_speed_m_s; end
    low_speed=V<=V_low;
end
if low_speed || V<=1e-6
    angle=pi/2; cosine=0; sine=1;
else
    cosine=min(1,max(-1,-w/V)); angle=acos(cosine); sine=Vuv/V;
end
if Vvw<=1, wing_angle=pi/2; else, wing_angle=acos(min(1,max(-1,-w/Vvw))); end
if Vuv<=1e-12, Sduct=0; Cduct=1; else, Sduct=u/Vuv; Cduct=v/Vuv; end
d=p.Duct;
T=d.k_T0*motor^2+V*motor*(d.k_Th+d.k_Ts*cosine)+V^2*ppval(d.dt,angle);
N=V*motor*d.k_Ns*sine+V^2*ppval(d.dn,angle);
M=N*d.l_cpz+T*d.k_cpx*V/motor*sine;
% 硬切换实测超过重量的百分之二；过渡区混合力和力矩，不混合迎角或跳过门禁。
blend=1;
if regularized_model && V_low>0 && V>V_low && V<2*V_low
    ratio=(V-V_low)/V_low; blend=ratio^2*(3-2*ratio);
    T90=d.k_T0*motor^2+V*motor*d.k_Th+V^2*ppval(d.dt,pi/2);
    N90=V*motor*d.k_Ns+V^2*ppval(d.dn,pi/2);
    M90=N90*d.l_cpz+T90*d.k_cpx*V/motor;
    T=(1-blend)*T90+blend*T;
    N=(1-blend)*N90+blend*N;
    M=(1-blend)*M90+blend*M;
end
Q=d.k_Q0*motor^2;
L=Vvw^2*ppval(p.Wing.wl,wing_angle);
D=Vvw^2*ppval(p.Wing.wd,wing_angle);
Mw=Vvw^2*ppval(p.Wing.wm,wing_angle);
radicand=(w/2)^2+T/(p.sd*p.den*p.S);
assert(isfinite(radicand) && radicand>=0,'当前气流超出出口风速公式的可用域，停止仿真。');
Ve=-w/2+sqrt(radicand);
C=p.d_cs*Ve^2*diag([p.l1,p.l1,p.l2])*p.P_cs;
% 真实舵效仅由对象读取；中性配置保留原矩阵及乘法次序。
gains=ones(6,1); mapping="linear"; dsat=deg2rad(28);
if isfield(cfg,'vane_gain_scale'), gains=cfg.vane_gain_scale(:); end
if isfield(cfg,'vane_deflection_map'), mapping=string(cfg.vane_deflection_map); end
if isfield(cfg,'vane_saturation_deg'), dsat=deg2rad(cfg.vane_saturation_deg); end
effective_delta=delta; slope=ones(6,1);
if mapping=="tanh"
    effective_delta=dsat*tanh(delta/dsat);
    slope=1-tanh(delta/dsat).^2;
elseif mapping=="stall"
    ratio=(delta/dsat).^2;
    effective_delta=delta./(1+ratio);
    slope=(1-ratio)./(1+ratio).^2;
end
if ~all(gains==1), C=C*diag(gains); end
Ma=[-M*Cduct-Mw-omega(1)*(p.k_my0+p.k_myv*Vvw);M*Sduct;0];
Mg=-p.FanDir*p.J_fan*motor*[omega(2);-omega(1);0];
out.force_body_n=[-N*Sduct;-N*Cduct-L;-T-D];
out.passive_torque_body_nm=Ma+Mg+[0;0;p.FanDir*(-Q+p.k_sta*Ve^2)];
if all(gains==1) && mapping=="linear"
    out.torque_body_nm=out.passive_torque_body_nm+C*delta;
else
    out.torque_body_nm=out.passive_torque_body_nm+C*effective_delta;
end
out.actual_torque_matrix=C;
out.effective_delta_rad=effective_delta;
% 六个无量纲局部增益；真实力矩雅可比的第i列为未缩放气流矩阵第i列乘此值。
out.vane_incremental_gain=gains.*slope;
out.exit_speed_m_s=Ve; out.airspeed_body_m_s=air;
out.thrust_n=T; out.duct_angle_rad=angle; out.wing_angle_rad=wing_angle;
out.low_speed_regularized=low_speed || (regularized_model && blend<1);
out.table_extrapolated=angle<p.duct_angle_range(1) || angle>p.duct_angle_range(2) ...
    || wing_angle<p.wing_angle_range(1) || wing_angle>p.wing_angle_range(2);
if out.table_extrapolated && string(cfg.aero_extrapolation_policy)=="error"
    error('ca:AeroTableDomain','迎角超出参考气动表范围：涵道%.3f度，机翼%.3f度。',rad2deg(angle),rad2deg(wing_angle));
end

end
