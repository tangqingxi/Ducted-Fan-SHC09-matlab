function ref=ca_f8_reference(cfg,spec,protocol)
% 九次相位速度平滑阶跃保证参考位置至四阶导数连续，所有前馈均来自计划轨迹。
ref=ca_reference(cfg);t=ref.time_s;start=protocol.motion_window_s(1);finish=protocol.motion_window_s(2);
ramp=protocol.phase_ramp_s;cruise=finish-start-2*ramp;assert(cruise>0);
S=fliplr(protocol.phase_speed_polynomial(:)');I=polyint(S);clock=zeros(numel(t),5);u=t-start;
q=u>0&u<ramp;z=u(q)/ramp;
clock(q,1)=ramp*polyval(I,z);
for order=1:4,clock(q,order+1)=ramp^(1-order)*polyval(derivative(S,order-1),z);end
q=u>=ramp&u<=ramp+cruise;clock(q,1)=ramp/2+u(q)-ramp;clock(q,2)=1;
q=u>ramp+cruise&u<2*ramp+cruise;z=(u(q)-ramp-cruise)/ramp;
clock(q,1)=ramp/2+cruise+ramp*(z-polyval(I,z));clock(q,2)=1-polyval(S,z);
for order=2:4,clock(q,order+1)=-ramp^(1-order)*polyval(derivative(S,order-1),z);end
q=u>=2*ramp+cruise;clock(q,1)=ramp+cruise;
phase=clock*(2*pi/spec.period_s);first=sine_derivatives(phase);second=sine_derivatives(2*phase);third=sine_derivatives(3*phase);
for order=0:4
    value=[spec.north_amplitude_m*first(:,order+1),spec.east_amplitude_m*second(:,order+1),zeros(numel(t),1)];
    if order==0,value(:,3)=-protocol.altitude_m;end
    fields=["position_ned_m","velocity_ned_m_s","acceleration_ned_m_s2","jerk_ned_m_s3","snap_ned_m_s4"];
    ref.(fields(order+1))=value;
end
yaw=deg2rad(spec.yaw_fundamental_deg)*first+deg2rad(spec.yaw_third_harmonic_deg)*third;
p=ca_shc09_parameters();
[ref.rotation_ff,ref.omega_body_rad_s,ref.alpha_body_rad_s2,ref.euler_rad]=ca_f8_attitude_reference( ...
    ref.acceleration_ned_m_s2,ref.jerk_ned_m_s3,ref.snap_ned_m_s4,yaw(:,1),yaw(:,2),yaw(:,3),p.g);
ref.yaw_rate_rad_s=yaw(:,2);ref.yaw_acceleration_rad_s2=yaw(:,3);ref.phase_rad=phase(:,1);
end

function value=derivative(value,order)
% 对已知参考多项式求解析导数，不对传感器或估计量数值差分。
for k=1:order,value=polyder(value);end
end

function result=sine_derivatives(phase)
% 截断泰勒级数递推计算复合正弦函数的零至四阶时间导数。
jet=phase./factorial(0:4);s=zeros(size(jet));c=s;s(:,1)=sin(jet(:,1));c(:,1)=cos(jet(:,1));
for order=1:4
    for j=1:order
        s(:,order+1)=s(:,order+1)+j*jet(:,j+1).*c(:,order-j+1)/order;
        c(:,order+1)=c(:,order+1)-j*jet(:,j+1).*s(:,order-j+1)/order;
    end
end
result=s.*factorial(0:4);
end
