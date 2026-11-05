function ref = ca_reference_to_b(ref,model)
% 将旧原生系(x左,y前,z下)表示的参考姿态/角速度/角加速度转换到真实 b 系。
% 旋转关系：R_b = R_old * R_old_to_b'；body 向量 v_b = R_old_to_b*v_old。
if isfield(ref,'frame') && string(ref.frame)=="b"
    return;
end
R=model.parameters.R_old_to_b;
if isfield(ref,'rotation')
    ref.rotation=rotate_reference(ref.rotation,R);
end
if isfield(ref,'rotation_ff')
    ref.rotation_ff=rotate_reference(ref.rotation_ff,R);
end
if isfield(ref,'omega_body_rad_s')
    ref.omega_body_rad_s=ref.omega_body_rad_s*R';
end
if isfield(ref,'alpha_body_rad_s2')
    ref.alpha_body_rad_s2=ref.alpha_body_rad_s2*R';
end
if isfield(ref,'gamma_body_rad_s2')
    ref.gamma_body_rad_s2=ref.gamma_body_rad_s2*R';
end
if isfield(ref,'rotation')
    n=size(ref.rotation,3);
    ref.euler_rad=zeros(n,3);
    for k=1:n
        ref.euler_rad(k,:)=ca_rotation_euler(ref.rotation(:,:,k))';
    end
elseif isfield(ref,'euler_rad')
    n=size(ref.euler_rad,1);
    for k=1:n
        Rb=ca_euler_rotation(ref.euler_rad(k,:)')*R';
        ref.euler_rad(k,:)=ca_rotation_euler(Rb)';
    end
end
ref.frame="b";
end

function R=rotate_reference(R,Rb)
if ndims(R)==2
    R=R*Rb';
else
    for k=1:size(R,3)
        R(:,:,k)=R(:,:,k)*Rb';
    end
end
end
