function y = Ducted_Fan_FnM(u,v,w,O,Duct_Config)

%----------------------------------------------------

%计算涵道力与力矩
%输入机体系三轴空速u,v,w，风扇转速O
%输出拉力、侧向力、俯仰力矩、涵道风扇扭矩y(1),y(2),y(3),y(4)， 全为标量

%----------------------------------------------------
%初始化

    k_T0  = Duct_Config.k_T0;   %跟C_T0相关 悬停时的拉力系数  
                                %k_T0 = 1/2 * 空气密度 * pi * C_T0 * R**4
    k_Th  = Duct_Config.k_Th;   %跟C_T_J0相关 
    k_Ts  = Duct_Config.k_Ts;   %跟C_T_J相关  拉力随a_df的衰减系数
    k_Ns  = Duct_Config.k_Ns;   %跟C_N_J相关  侧向力力随a_df的衰减系数
    k_Q0  = Duct_Config.k_Q0;   %跟C_Q相关    风扇扭矩系数
    l_cpz = Duct_Config.l_cpz;  %跟l_N相关    侧向力N_df对机体中心的力臂
    k_cpx = Duct_Config.k_cpx;  %跟l_T相关    拉力中心的法向偏移
    dt    = Duct_Config.dt;     %涵道拉力系数
    dn    = Duct_Config.dn;     %涵道侧向力系数
    
%----------------------------------------------------
%计算AOA迎角（论文中的a_df）
    Va_min = 1e-6;

    Vuv = sqrt( u^2 + v^2 );             %气流沿涵道平面横向扫过的速度大小
    Va_body  = sqrt( u^2 + v^2 + w^2);   %机体系下相对速度的总大小
    if ( Va_body <= Va_min )
        AOA   = pi/2;
        csAOA = 0;
        sAOA  = 1;
    else
        csAOA = -w/Va_body;
        csAOA = max(min(csAOA,1),-1);    % 防止数值误差导致 acos 出错

        AOA   = acos(csAOA);      %相对速度方向与机体 -z 轴方向之间的夹角
        sAOA  = Vuv/Va_body;
    end
    
%----------------------------------------------------
%计算拉力、侧向力、俯仰力矩、风扇扭矩
    
    y(1) = k_T0*O^2 + Va_body*O*( k_Th + k_Ts*csAOA ) + Va_body^2*ppval(dt,AOA);
    y(2) = Va_body*O*k_Ns*sAOA + Va_body^2*ppval(dn,AOA);
    if ( O>0 )
        y(3) = y(2)*l_cpz + y(1)*k_cpx*Va_body/O*sAOA;
    else
        y(3) = y(2)*l_cpz;
    end
    y(4) = k_Q0*O^2;
%----------------------------------------------------

end