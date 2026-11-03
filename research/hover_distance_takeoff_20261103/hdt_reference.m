function ref=hdt_reference(p,sample_hz)
% 独立起飞参考；五次位置曲线及偏航积分均解析计算，不改旧40秒参考。
t=(0:round(p.duration_s*sample_hz))'/sample_hz;u=min(1,max(0,t/p.takeoff_s));
s=10*u.^3-15*u.^4+6*u.^5;ds=(30*u.^2-60*u.^3+30*u.^4)/p.takeoff_s;
dds=(60*u-180*u.^2+120*u.^3)/p.takeoff_s^2;
delta=p.position_ned_m(:)'-p.initial_position_ned_m(:)';
position=p.initial_position_ned_m(:)'+s.*delta;velocity=ds.*delta;acceleration=dds.*delta;
w=2*pi*p.yaw_frequency_hz;T=p.yaw_ramp_s;start=p.yaw_start_s;finish=p.duration_s-T;
z=min(1,max(0,(t-start)/T));up=10*z.^3-15*z.^4+6*z.^5;
dup=(30*z.^2-60*z.^3+30*z.^4)/T;dup(t<start|t>=start+T)=0;
z=min(1,max(0,(t-finish)/T));down=1-10*z.^3+15*z.^4-6*z.^5;
ddown=-(30*z.^2-60*z.^3+30*z.^4)/T;ddown(t<finish)=0;
phase=t-p.yaw_phase_origin_s;amplitude=deg2rad(p.yaw_rate_peak_deg_s);
rate=amplitude*up.*down.*sin(w*phase);
gamma=amplitude*((dup.*down+up.*ddown).*sin(w*phase)+w*up.*down.*cos(w*phase));
first=[0,0,0,10/T^3,-15/T^4,6/T^5];last=[1,0,0,-10/T^3,15/T^4,-6/T^5];
yaw=zeros(size(t));a=t>=start&t<=start+T;b=t>start+T&t<finish;c=t>=finish;
initial=integral_sine(T,start-p.yaw_phase_origin_s,first,w);
ending=initial+(cos(w*(start+T-p.yaw_phase_origin_s))-cos(w*(finish-p.yaw_phase_origin_s)))/w;
yaw(a)=integral_sine(t(a)-start,start-p.yaw_phase_origin_s,first,w);
yaw(b)=initial+(cos(w*(start+T-p.yaw_phase_origin_s))-cos(w*phase(b)))/w;
yaw(c)=ending+integral_sine(t(c)-finish,finish-p.yaw_phase_origin_s,last,w);yaw=amplitude*yaw;
ref=struct('time_s',t,'position_ned_m',position,'velocity_ned_m_s',velocity, ...
    'acceleration_ned_m_s2',acceleration,'euler_rad',[zeros(numel(t),2),yaw], ...
    'omega_body_rad_s',[zeros(numel(t),2),rate],'alpha_body_rad_s2',[zeros(numel(t),2),gamma], ...
    'rotation_ff',zeros(3,3,numel(t)));
for k=1:numel(t),ref.rotation_ff(:,:,k)=ca_euler_rotation(ref.euler_rad(k,:)');end
assert(isequal(position(1,:),[0,0,0])&&isequal(position(end,:),[0,0,-10]));
assert(max(abs(velocity([1,round(p.takeoff_s*sample_hz)+1,end],:)),[],'all')<1e-12);
assert(max(abs(acceleration([1,round(p.takeoff_s*sample_hz)+1,end],:)),[],'all')<1e-12);
assert(max(abs(rate(t<=start)))<1e-12&&abs(rate(end))<1e-12);
end

function value=integral_sine(u,start,c,w)
% 多项式乘正弦的定积分，允许收尾航向不为零。
u=u(:);e=exp(1i*w*u);I=(e-1)/(1i*w);total=c(1)*I;
for n=1:numel(c)-1,I=u.^n.*e/(1i*w)-n*I/(1i*w);total=total+c(n+1)*I;end
value=imag(exp(1i*w*start)*total);
end
