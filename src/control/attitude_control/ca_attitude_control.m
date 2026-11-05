function [omega_reference,alpha_reference] = ca_attitude_control(rotation,omega,desired_rotation,desired_omega,desired_alpha,cfg)
% 所有分配方法共用相同的几何姿态控制器。
relative=rotation'*desired_rotation;
relative_dot=-ca_skew(omega)*relative+relative*ca_skew(desired_omega);
e=0.5*vee(relative-relative');
e_dot=0.5*vee(relative_dot-relative_dot');
omega_reference=relative*desired_omega+cfg.attitude_gain(:).*e;
alpha_reference=relative_dot*desired_omega+relative*desired_alpha+cfg.attitude_gain(:).*e_dot;
end
function vector=vee(matrix)
% 提取反对称矩阵对应向量。
vector=[matrix(3,2);matrix(1,3);matrix(2,1)];
end
