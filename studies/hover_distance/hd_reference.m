function ref=hd_reference(p,sample_hz,peak_deg_s)
% 定点位置、零规划滚转俯仰；对平滑正弦偏航速率解析积分得到连续角度。
t=(0:round(p.duration_s*sample_hz))'/sample_hz;w=2*pi*p.yaw_frequency_hz;T=p.yaw_ramp_s;amplitude=deg2rad(peak_deg_s);
z=min(1,max(0,t/T));up=10*z.^3-15*z.^4+6*z.^5;dup=(30*z.^2-60*z.^3+30*z.^4)/T;dup(t>=T)=0;
z=min(1,max(0,(t-(p.duration_s-T))/T));down=1-(10*z.^3-15*z.^4+6*z.^5);
ddown=-(30*z.^2-60*z.^3+30*z.^4)/T;ddown(t<p.duration_s-T)=0;
envelope=up.*down;derivative=dup.*down+up.*ddown;
rate=amplitude*envelope.*sin(w*t);gamma=amplitude*(derivative.*sin(w*t)+w*envelope.*cos(w*t));
first=[0,0,0,10/T^3,-15/T^4,6/T^5];last=[1,0,0,-10/T^3,15/T^4,-6/T^5];
yaw=zeros(size(t));a=t<=T;b=t>T&t<p.duration_s-T;c=t>=p.duration_s-T;
initial=integral_sine(T,0,first,w);end_cruise=initial+(cos(w*T)-cos(w*(p.duration_s-T)))/w;
yaw(a)=integral_sine(t(a),0,first,w);
yaw(b)=initial+(cos(w*T)-cos(w*t(b)))/w;
yaw(c)=end_cruise+integral_sine(t(c)-(p.duration_s-T),p.duration_s-T,last,w);yaw=amplitude*yaw;
ref=struct('time_s',t,'position_ned_m',repmat(p.position_ned_m(:)',numel(t),1), ...
    'velocity_ned_m_s',zeros(numel(t),3),'acceleration_ned_m_s2',zeros(numel(t),3), ...
    'euler_rad',[zeros(numel(t),2),yaw],'omega_body_rad_s',[zeros(numel(t),2),rate], ...
    'alpha_body_rad_s2',[zeros(numel(t),2),gamma],'rotation_ff',zeros(3,3,numel(t)));
for k=1:numel(t),ref.rotation_ff(:,:,k)=ca_euler_rotation(ref.euler_rad(k,:)');end
assert(max(abs(yaw([1,end])))<1e-10&&max(abs(rate))<=amplitude+1e-12);
end

function value=integral_sine(u,start,coefficients,w)
% 多项式乘正弦的复指数递推积分，避免差分估计角加速度。
u=u(:);exponent=exp(1i*w*u);I=(exponent-1)/(1i*w);total=coefficients(1)*I;
for n=1:numel(coefficients)-1
    I=u.^n.*exponent/(1i*w)-n*I/(1i*w);total=total+coefficients(n+1)*I;
end
value=imag(exp(1i*w*start)*total);
end
