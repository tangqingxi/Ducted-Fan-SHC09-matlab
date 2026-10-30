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
p.S=pi*0.114^2; p.m=2.1; p.J=diag([0.0438,0.0436,0.005006]);
p.J_fan=0.000037; p.sd=0.7; p.FanDir=1; p.d_cs=0.0032;
p.k_sta=5.3688e-4; p.l1=0.267; p.l2=0.066;
p.P_cs=[0,-sqrt(3)/2,-sqrt(3)/2,0,sqrt(3)/2,sqrt(3)/2; ...
    -1,-0.5,0.5,1,0.5,-0.5;ones(1,6)];
p.cm=deg2rad(40); p.omega_m_min=200; p.omega_m_max=1200;
p.k_my0=0.0198; p.k_myv=0.0015;
p.g=9.788; p.den=1.225; p.G=[0;0;p.m*p.g];
p.duct_angle_range=[min(d.duct_raw(:,1)),max(d.duct_raw(:,1))];
p.wing_angle_range=[min(w.wing_raw(:,1)),max(w.wing_raw(:,1))];
end
