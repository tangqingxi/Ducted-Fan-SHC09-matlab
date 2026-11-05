function p = ca_shc09_parameters()
% 参数、数据列和样条定义逐项对应参考工程的初始化函数。
folder=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(folder));
reference=fullfile(root,'models','shc09','reference');
d=load(fullfile(reference,'duct_raw.mat'));
w=load(fullfile(reference,'wing_raw.mat'));
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
% 真实 b 系：b1右、b2下、b3垂直截面入纸（向下）；与旧原生系 (x左,y前,z下)
% 的关系为 R=diag([-1,-1,1])。b3 是截面法向，不是轴向平移坐标。
p.R_old_to_b=diag([-1,-1,1]);
p.C_old_to_frd=[0,1,0;-1,0,0;0,0,1];
% PX4/SDF 的惯量按 FRD 给出：Jx=0.0438, Jy=0.0436, Jz=0.005006。
% b1=FRD y, b2=-FRD x, b3=FRD z，所以 J_b=diag([Jy,Jx,Jz])。
p.J_frd=diag([0.0438,0.0436,0.005006]);
p.J_b=diag([p.J_frd(2,2),p.J_frd(1,1),p.J_frd(3,3)]);
p.J=p.J_b;
p.J_fan=0.000037; p.sd=0.7; p.FanDir=1; p.d_cs=0.0032;
p.k_sta=5.3688e-4; p.l1=0.267; p.l2=0.066;
% 旧 P_cs 是 SDF B 在旧原生系下的表达（C'*B_sdf），保留作历史基线。
p.P_cs=[0,-sqrt(3)/2,-sqrt(3)/2,0,sqrt(3)/2,sqrt(3)/2; ...
    -1,-0.5,0.5,1,0.5,-0.5;ones(1,6)];
% 新 b 系 B：P_b=R*P_old；列仍为真实舵面1-6。
p.P_cs_b=p.R_old_to_b*p.P_cs;
p.arm_diag_b=diag([p.l1,p.l1,p.l2]);
% 六舵平面位置由 0/60/.../300 deg 与 l1 确定；b3 安装坐标无 SDF/CAD 证据。
theta=deg2rad(0:60:300);
p.vane_theta_rad=theta;
p.hinges_b=[p.l1*cos(theta(:)),p.l1*sin(theta(:)),nan(6,1)];
p.hinges_b_planar=p.hinges_b(:,1:2);
p.hinge_axial_offset_m=NaN;
p.hinge_axial_status="unknown_no_sdf_cad_evidence";
% l2 仅是 yaw 控制效能等效力臂；不是安装 b3 坐标，也不是舵面中心距。
p.l2_yaw_arm_m=p.l2;
p.hinges_m=p.hinges_b;
p.coordinate_frame='b';
p.cm=deg2rad(40); p.omega_m_min=200; p.omega_m_max=1200;
p.k_my0=0.0198; p.k_myv=0.0015;
p.g=9.788; p.den=1.225; p.G=[0;0;p.m*p.g];
p.duct_angle_range=[min(d.duct_raw(:,1)),max(d.duct_raw(:,1))];
p.wing_angle_range=[min(w.wing_raw(:,1)),max(w.wing_raw(:,1))];
end
