function SHC09 = Initialized_SHC09(duct_raw, wing_raw, g, d2r)

    %SHC09 飞行器型号
    %spline生成了三次样条插值，得到比较光滑的曲线，其中包含了一些常数了。
    Wing_Config.wl = spline(wing_raw(:,1),wing_raw(:,2));  %机翼升力系数
    Wing_Config.wd = spline(wing_raw(:,1),wing_raw(:,3));  %机翼侧向力系数
    Wing_Config.wm = spline(wing_raw(:,1),wing_raw(:,4));  %机翼俯仰力矩系数

    Duct_Config.dt = spline(duct_raw(:,1),duct_raw(:,2));  %涵道拉力系数
    Duct_Config.dn = spline(duct_raw(:,1),duct_raw(:,3));  %涵道侧向力系数
    Duct_Config.dm = spline(duct_raw(:,1),duct_raw(:,4));

    Duct_Config.k_T0  =  2.8964e-05; %跟C_T0相关 悬停时的拉力系数
                                     %k_T0 = 1/2 * 空气密度 * pi * C_T0 * R**4
    Duct_Config.k_Th  = -3.7614e-04; %跟C_T_J0相关
    Duct_Config.k_Ts  = -2.6733e-04; %跟C_T_J相关  拉力随a_df的衰减系数

    Duct_Config.k_Ns  =  5.0699e-04; %跟C_N_J相关  侧向力力随a_df的衰减系数
    Duct_Config.k_Q0  =  5.7792e-07; %跟C_Q相关    风扇扭矩系数
    Duct_Config.l_cpz = -0.15;       %跟l_N相关    侧向力N_df对机体中心的力臂
    Duct_Config.k_cpx =  2.6619;     %跟l_T相关    拉力中心的法向偏移


    SHC09.Duct = Duct_Config;
    SHC09.Wing = Wing_Config;
    SHC09.S     = pi*0.114^2; %文章中的A_f  风扇桨盘面积
    SHC09.m     = 2.1;        %SHC09机型的质量
    SHC09.J     = diag([0.0438, 0.0436, 0.005006]); %机体转动惯量矩阵
    SHC09.J_fan = 0.000037;   %风扇转动惯量

    SHC09.sd     = 0.7;        %2.3.1节 涵道风扇的涵道扩压比
    SHC09.FanDir = 1;          %风扇转动方向，1表示CW（顺时针），-1表示CCW（逆时针）
    SHC09.d_cs   = 0.0032;     %单个舵面的力矩系数
    SHC09.k_sta  = 5.3688e-04; %固定片扭矩系数
    SHC09.l1     = 0.267;      %舵机面中心到SHC09重心的力臂
    SHC09.l2     = 0.066;      %5，6舵面中心点间的力臂

    % P_cs 为舵面几何/符号矩阵，M_cs = d_cs*Ve^2*diag([l1,l1,l2])*P_cs*u。
    SHC09.P_cs = [  0  , -sqrt(3)/2 , -sqrt(3)/2 , 0 , sqrt(3)/2 , sqrt(3)/2 ;
                   -1  ,   -0.5     ,     0.5    , 1 ,    0.5    ,   -0.5    ;
                    1  ,    1       ,     1      , 1 ,    1      ,    1      ; ];

    SHC09.cm = 40*d2r;              % 舵面限幅，单位 rad
    SHC09.omega_m_max = 1200;       % 最高涵道转速
    SHC09.omega_m_min = 200;        % 最低涵道转速

    SHC09.k_my0 = 0.0198; %俯仰阻尼
    SHC09.k_myv = 0.0015;
    SHC09.G = [ 0 ; 0 ; SHC09.m*g ]; %SHC09机型的重力

end
