function [ref, protocol] = ca_figure8_reference(cfg)
% 用连续的相位时钟生成水平八字；只提供参考，不修改现有控制器。
hover=6;ramp=4;period=20;cycles=2;settle=2;amplitude=[2,1];
cruise=cycles*period-ramp;motion_end=hover+2*ramp+cruise;
assert(abs(cfg.duration_s-(motion_end+settle))<1e-10,'八字协议总时长必须为52秒。');
ref=ca_reference(cfg);t=ref.time_s;u=t-hover;
clock=zeros(size(t));speed=clock;acceleration=clock;
q=u>0 & u<ramp;z=u(q)/ramp;
clock(q)=ramp*(2.5*z.^4-3*z.^5+z.^6);
speed(q)=10*z.^3-15*z.^4+6*z.^5;
acceleration(q)=(30*z.^2-60*z.^3+30*z.^4)/ramp;
q=u>=ramp & u<=ramp+cruise;
clock(q)=ramp/2+u(q)-ramp;speed(q)=1;
q=u>ramp+cruise & u<2*ramp+cruise;z=(u(q)-ramp-cruise)/ramp;
clock(q)=ramp/2+cruise+ramp*(z-2.5*z.^4+3*z.^5-z.^6);
speed(q)=1-(10*z.^3-15*z.^4+6*z.^5);
acceleration(q)=-(30*z.^2-60*z.^3+30*z.^4)/ramp;
clock(u>=2*ramp+cruise)=cycles*period;
phase=2*pi*clock/period;rate=2*pi*speed/period;rate_dot=2*pi*acceleration/period;
ref.position_ned_m=[amplitude(1)*sin(phase),amplitude(2)*sin(2*phase),-10*ones(size(t))];
ref.velocity_ned_m_s=[amplitude(1)*cos(phase).*rate,2*amplitude(2)*cos(2*phase).*rate,zeros(size(t))];
ref.acceleration_ned_m_s2=[amplitude(1)*(cos(phase).*rate_dot-sin(phase).*rate.^2), ...
    2*amplitude(2)*(cos(2*phase).*rate_dot-2*sin(2*phase).*rate.^2),zeros(size(t))];
ref.euler_rad(:)=0;ref.euler_dot_rad_s(:)=0;ref.euler_ddot_rad_s2(:)=0;
ref.omega_body_rad_s(:)=0;ref.alpha_body_rad_s2(:)=0;
protocol=struct('name',"figure8_lite_M2b",'duration_s',cfg.duration_s,'period_s',period, ...
    'amplitude_ned_m',[amplitude,0],'altitude_m',10,'yaw_deg',0,'cycles',cycles, ...
    'hover_s',hover,'phase_ramp_s',ramp,'motion_end_s',motion_end, ...
    'evaluation_window_s',[hover,motion_end],'cruise_window_s',[hover+ramp,motion_end-ramp], ...
    'velocity_reference_role',"几何导数，仅用于评价，现有位置环不接收速度前馈", ...
    'attitude_reference_role',"各方法位置环实际生成的姿态指令，不是独立共同给定", ...
    'rate_reference_role',"各方法姿态环实际生成的机体角速度指令", ...
    'load_fraction',0.6,'command_limit_deg',40);
end
