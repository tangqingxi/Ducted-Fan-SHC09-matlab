function matrix = ca_skew(vector)
% 三维向量对应的反对称矩阵。
matrix=[0,-vector(3),vector(2);vector(3),0,-vector(1);-vector(2),vector(1),0];
end
