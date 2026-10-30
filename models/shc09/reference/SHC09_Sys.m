function [dx, Force, State] = SHC09_Sys(~, x, DUCTFAN, Env, Actuator, Disturbance, Force, State)

%----------------------------------------------------

%SHC09飞行器动态系统微分模型，用以 ode45 求解动态响应
%坐标系定义：前向y，轴向z，侧向x，飞行器沿滚转正向倾倒对应前向过渡
%初始状态：姿态0点对应垂直悬停状态
%输入NED位置X,Y,Z，NED速度Vx,Vy,Vz，姿态角Roll,Pitch, Yaw，俯仰角速度p,q,r，对应x=[X,Y,Z,Vx,Vy,Vz,Roll,Pitch,Yaw,p,q,r]
%u,v,w定义：机体系空速
%输入结构体包括构型参数 DUCTFAN、执行机构 Actuator、环境 Env 和扰动 Disturbance

% 当前采用局部积分时间，每一步积分区间均为 [0, ts]
% 若后续扰动、轨迹或控制输入与全局时间有关，应改为 [time(i), time(i)+ts]
%----------------------------------------------------
% 原脚本使用过 global 变量；当前版本通过函数参数和结构体传递数据
    den   = Env.den;                      %空气密度                         
    g     = Env.g  ;                      %重力加速度
    P_cs  = DUCTFAN.P_cs;                 %舵面力矩分配系数矩阵
    sd    = DUCTFAN.sd;                   %2.3.1节 涵道风扇的涵道扩压比
    Dir   = DUCTFAN.FanDir;               %风扇转动方向，1表示CW，-1表示CCW
    S     = DUCTFAN.S;                    %文章中的A_f  风扇桨盘面积
    m     = DUCTFAN.m;                    %SHC09机型的质量
    J     = DUCTFAN.J;                    %机体转动惯量矩阵
    J_fan = DUCTFAN.J_fan;                %风扇转动惯量
    cm    = DUCTFAN.cm;                   %舵面限幅，单位 rad
    omega_m_min = DUCTFAN.omega_m_min;    %最低涵道转速
    omega_m_max = DUCTFAN.omega_m_max;    %最高涵道转速
    d_cs  = DUCTFAN.d_cs;                 %单个舵面的力系数
    k_sta = DUCTFAN.k_sta;                %固定片扭矩系数
    l1    = DUCTFAN.l1;                   %图2-1（b）中的力臂l1 舵机面中心到SHC09重心的力臂
    l2    = DUCTFAN.l2;                   %图2-1（b）中的力臂l2 5，6舵面中心点间的力臂
    Duct  = DUCTFAN.Duct;                 %涵道相关系数
    Wing  = DUCTFAN.Wing;                 %机翼相关系数
    k_my0 = DUCTFAN.k_my0;                %非轴流俯仰阻尼系数
    k_myv = DUCTFAN.k_myv;
    if isvector(J)
        J = diag(J(:));
    end

    u_cs  = Actuator.u;                   %控制舵面的转角，单位 rad
    omega_m = Actuator.omega_m;           %风扇转速
    
    Dx    = Disturbance.Dx;               %风速
    Dy    = Disturbance.Dy;
    Dz    = Disturbance.Dz;

    if isfield(Disturbance, 'Fx')
        F_dist_n = [
            Disturbance.Fx;
            Disturbance.Fy;
            Disturbance.Fz
        ];
    else
        F_dist_n = [0; 0; 0];
    end
   
    Vx    = x(4);                         %状态向量 x = [位置; 速度; 欧拉角; 机体系角速度]
    Vy    = x(5);
    Vz    = x(6);
    Roll  = x(7);
    Pitch = x(8);
    Yaw   = x(9);
    p     = x(10);
    q     = x(11);
    r     = x(12);
    
    dx    = zeros(12,1);                  %ODE 右端导数 dx/dt
    
    
    Vn   = [ Vx ; Vy ; Vz ];              %速度向量
    W    = [ p ; q ; r ];                 %角速度
    Rn2b = Rn2bf(Roll,Pitch,Yaw);         %导航系到机体系的旋转矩阵
    
    Q    = [1    sin(Roll)*tan(Pitch)    cos(Roll)*tan(Pitch);
            0        cos(Roll)               -sin(Roll)      ;
            0    sin(Roll)*sec(Pitch)    cos(Roll)*sec(Pitch)];
                                          %把机体系角速度 p, q, r 转成欧拉角变化率
    
    Va = Rn2b*[ (Vx - Dx) ; (Vy - Dy) ; (Vz - Dz) ];
                                          %飞行器相对空气的速度 = 飞行器地速 - 风速（Disturbance）
                                          %论文中的空速Va
    u  = Va(1);
    v  = Va(2);
    w  = Va(3);

    % 动力学入口保留最后一道物理限幅，防止异常执行器状态进入模型。
    u_cs = min(max(u_cs(:), -cm), cm);
    omega_m = Constrain(omega_m, omega_m_min, omega_m_max);

    %空速、迎角（机体）
    
    Vvw = sqrt( v^2 + w^2 );            %yz-plane空速分量
    Vuv = sqrt( u^2 + v^2 );
    Vuv_min = 1e-12;
    
    if ( Vvw <= 1 )                     %当 Vvw 较小时，v-w 平面内的相对速度模长很小，
        AOA = pi/2;                     %此时迎角计算对数值误差非常敏感，将迎角设为 pi/2。    
    else                                %坐标系定义：前向y，轴向z，侧向x，飞行器沿滚转正向倾倒对应前向过渡
        AOA = acos( -w/Vvw );
    end
    if ( Vuv <= Vuv_min )
        Sduct = 0;
        Cduct = 1;
    else
        Sduct = u/Vuv;
        Cduct = v/Vuv;
    end
 %--------------------------------------------------------
    %计算力与力矩
    
    y1 = Ducted_Fan_FnM(u,v,w,omega_m,Duct); %涵道
    %涵道拉力、侧向力、及拉力-侧向力产生的涵道俯仰力矩力矩、风扇扭矩——为标量
    %使用新的机体系空速计算，需要投影到当前机体系
    %输出拉力、侧向力、涵道俯仰力矩、涵道风扇扭矩y11(1),y1(2),y1(3),y1(4)
    y2 = Wing_FnM(Vvw,AOA,Wing); %机翼
    %机翼升阻力和滚转力矩，由样条插值产生，需要投影到机体系。这里有数据库决定了正负号，力分别在y，z轴，力矩在x轴。
    %升力相关项 y2(1)、阻力相关项 y2(2)，以及绕机体 x 轴的俯仰力矩 y2(3)
    
    
    Ve = -w/2 + sqrt( (w/2)^2 + y1(1)/(sd*den*S) ); %出口风速
    F1 = -y1(2)*Sduct;
    F2 = -y1(2)*Cduct + -y2(1);
    F3 = -y1(1) + -y2(2);
    F  = [ F1 ; F2 ; F3 ];
    
    M_my        = -p*k_my0 + -p*k_myv*Vvw;   %涵道非轴流时
    M_fan       = -Dir*y1(4);                %涵道风扇扭矩
    M_sta       =  Dir*k_sta*Ve^2;           %涵道中固定叶片反扭矩，用以抵消M_fan
    M_gyro      = -Dir*J_fan*omega_m*[ q ; -p ; 0 ];   %陀螺力矩
    M_aero(1,1) = -y1(3)*Cduct + -y2(3) + M_my;
    M_aero(2,1) =  y1(3)*Sduct ;
    M_aero(3,1) =  0 ;
    M_cs        =  d_cs*Ve^2*diag([l1,l1,l2])*P_cs*u_cs;
    M           =  M_aero + M_gyro + M_cs + [ 0 ; 0 ; M_fan + M_sta] ...
                        + [Disturbance.Mx ;Disturbance.My ;Disturbance.Mz];
    
 %-------------------------------------------------------
    %动力学方程
    
    dx(1:3)   = Vn;
    % 平动外力扰动定义在 NED 惯性系中，直接叠加到平动动力学。
    dx(4:6)   = Rn2b'*F./m + F_dist_n./m + [ 0 ; 0 ; g ];
    dx(7:9)   = Q*W;
    dx(10:12) = J\(M - cross(W,(J*W)));
    
 %----------------------------------------------------
    % 保存当前状态下的气动力信息
    % 加速度计测到的是机体系非重力比力。若存在 NED 平动外力，
    % 需要先转换到机体系后再写入 Force，供 StateSensing 读取。
    F_sensor_b = F + Rn2b * F_dist_n;

    Force.Fx = F_sensor_b(1);
    Force.Fy = F_sensor_b(2);
    Force.Fz = F_sensor_b(3);
    % 保存当前状态下的出口风速信息
    State.Ve  = Ve;
    
end
