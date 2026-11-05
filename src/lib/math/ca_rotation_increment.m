function rotation = ca_rotation_increment(vector)
% 旋转向量的指数映射，避免欧拉角积分的奇异点。
angle=norm(vector); matrix=ca_skew(vector);
if angle<1e-8
    rotation=eye(3)+matrix+0.5*matrix*matrix;
else
    rotation=eye(3)+sin(angle)/angle*matrix+(1-cos(angle))/angle^2*(matrix*matrix);
end
end
