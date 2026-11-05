function angles = ca_rotation_euler(rotation)
% 旋转矩阵到欧拉角，仅用于输出和图表。
angles=[atan2(rotation(3,2),rotation(3,3));asin(min(1,max(-1,-rotation(3,1))));atan2(rotation(2,1),rotation(1,1))];
end
