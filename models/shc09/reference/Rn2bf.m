function Rn2b = Rn2bf(Roll, Pitch, Yaw)
    % 根据滚转角、俯仰角、偏航角计算导航系到机体系的旋转矩阵
    % Roll  为滚转角，单位为 rad
    % Pitch 为俯仰角，单位为 rad
    % Yaw   为偏航角，单位为 rad

    c_phi   = cos(Roll);
    s_phi   = sin(Roll);
    c_theta = cos(Pitch);
    s_theta = sin(Pitch);
    c_psi   = cos(Yaw);
    s_psi   = sin(Yaw);

    Rn2b = [
        c_theta*c_psi,                          c_theta*s_psi,                         -s_theta;
        -c_phi*s_psi + s_phi*s_theta*c_psi,     c_phi*c_psi + s_phi*s_theta*s_psi,      s_phi*c_theta;
         s_phi*s_psi + c_phi*s_theta*c_psi,    -s_phi*c_psi + c_phi*s_theta*s_psi,      c_phi*c_theta
    ];
end