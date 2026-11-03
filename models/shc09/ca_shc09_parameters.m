function p = ca_shc09_parameters()
% 参数、数据列和样条定义逐项对应参考工程的初始化函数。
folder=fileparts(mfilename('fullpath'));
d=load(fullfile(folder,'reference','duct_raw.mat'));
w=load(fullfile(folder,'reference','wing_raw.mat'));
p.Wing.wl=spline(w.wing_raw(:,1),w.wing_raw(:,2));
p.Wing.wd=spline(w.wing_raw(:,1),w.wing_raw(:,3));
p.Wing.wm=spline(w.wing_raw(:,1),w.wing_raw(:,4));
p.Duct.dt=spline(d.duct_raw(:,1),d.duct_raw(:,2));
p.Duct.dn=spline(d.duct_raw(:,1),d.duct_raw(:,3));
p.Duct.dm=spline(d.duct_raw(:,1),d.duct_raw(:,4));
p.Duct.k_T0=2.8964e-5; p.Duct.k_Th=-3.7614e-4;
p.Duct.k_Ts=-2.6733e-4; p.Duct.k_Ns=5.0699e-4;
p.Duct.k_Q0=5.7792e-7; p.Duct.l_cpz=-0.15; p.Duct.k_cpx=2.6619;
p.S=pi*0.114^2; p.m=2.1;
% 真实 b 系：b1右、b2下、b3入纸；与旧原生系 (x左,y前,z下) 的旋转为 R=diag(-1,-1,1)。
p.R_old_to_b=diag([-1,-1,1]);
% PX4/SDF 的惯量按 FRD 给出：Jx=0.0438, Jy=0.0436, Jz=0.005006。
% b1=FRD y, b2=-FRD x, b3=FRD z，所以 J_b=diag([Jy,Jx,Jz])，前两项顺序交换。
p.J_frd=diag([0.0438,0.0436,0.005006]);
% b1=FRD y, b2=-FRD x, b3=FRD z：这是轴交换，不是仅靠 R 的符号旋转。
p.J_b=diag([p.J_frd(2,2),p.J_frd(1,1),p.J_frd(3,3)]);
p.J=p.J_b;
p.J_fan=0.000037; p.sd=0.7; p.FanDir=1; p.d_cs=0.0032;
p.k_sta=5.3688e-4; p.l1=0.267; p.l2=0.066;
% 旧 P_cs 是 SDF B 在旧原生系下的表达（C'*B_sdf），保留作历史基线。
p.P_cs=[0,-sqrt(3)/2,-sqrt(3)/2,0,sqrt(3)/2,sqrt(3)/2; ...
    -1,-0.5,0.5,1,0.5,-0.5;ones(1,6)];
% 换到真实 b 系后仅旋转行：B_b = R*P_old；列仍为真实舵面1-6。
p.P_cs_b=p.R_old_to_b*p.P_cs;
% 真实安装几何：0,60,...,300 deg；l2 是关节 b3 坐标（不是 yaw 力臂）。
theta=deg2rad(0:60:300);
p.vane_theta_rad=theta;
p.hinges_b=[p.l1*cos(theta(:)),p.l1*sin(theta(:)),p.l2*ones(6,1)];
p.hinges_m=p.hinges_b;
p.coordinate_frame='b';
p.cm=deg2rad(40); p.omega_m_min=200; p.omega_m_max=1200;
p.k_my0=0.0198; p.k_myv=0.0015;
p.g=9.788; p.den=1.225; p.G=[0;0;p.m*p.g];
p.duct_angle_range=[min(d.duct_raw(:,1)),max(d.duct_raw(:,1))];
p.wing_angle_range=[min(w.wing_raw(:,1)),max(w.wing_raw(:,1))];
end
