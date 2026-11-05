function [rotation,omega,alpha,euler] = ca_f8_attitude_reference(acceleration,jerk,snap,yaw,yaw_rate,yaw_acceleration,g)
% 由解析平移导数与航向导数构造精确航向姿态及其机体系角速度、角加速度。
n=size(acceleration,1);rotation=zeros(3,3,n);omega=zeros(n,3);alpha=zeros(n,3);euler=zeros(n,3);
for k=1:n
    f=[0;0;g]-acceleration(k,:)';f1=-jerk(k,:)';f2=-snap(k,:)';
    length_f=norm(f);assert(length_f>1e-6,'F8参考比力接近零。');
    b=f/length_f;length1=dot(b,f1);length2=(dot(f1,f1)+dot(f,f2)-length1^2)/length_f;
    b1=(f1-b*length1)/length_f;b2=(f2-b*length2-2*b1*length1)/length_f;
    psi=yaw(k);psi1=yaw_rate(k);psi2=yaw_acceleration(k);c=cos(psi);s=sin(psi);
    A=[c,s,0;-s,c,0;0,0,1];D=[-s,c,0;-c,-s,0;0,0,0];DD=[-c,-s,0;s,-c,0;0,0,0];
    u=A*b;u1=A*b1+psi1*D*b;u2=A*b2+2*psi1*D*b1+psi2*D*b+psi1^2*DD*b;
    d=sqrt(1-u(2)^2);assert(d>1e-4,'F8参考进入欧拉角奇异区。');
    phi=asin(-u(2));phi1=-u1(2)/d;phi2=-u2(2)/d-u(2)*u1(2)^2/d^3;
    denominator=u(1)^2+u(3)^2;numerator=u(3)*u1(1)-u(1)*u1(3);
    theta=atan2(u(1),u(3));theta1=numerator/denominator;
    theta2=(u(3)*u2(1)-u(1)*u2(3))/denominator ...
        -numerator*2*(u(1)*u1(1)+u(3)*u1(3))/denominator^2;
    angles=[phi;theta;psi];rates=[phi1;theta1;psi1];accelerations=[phi2;theta2;psi2];
    E=[1,0,-sin(theta);0,cos(phi),sin(phi)*cos(theta);0,-sin(phi),cos(phi)*cos(theta)];
    E1=[0,0,-cos(theta)*theta1;0,-sin(phi)*phi1,cos(phi)*phi1*cos(theta)-sin(phi)*sin(theta)*theta1; ...
        0,-cos(phi)*phi1,-sin(phi)*phi1*cos(theta)-cos(phi)*sin(theta)*theta1];
    rotation(:,:,k)=ca_euler_rotation(angles);euler(k,:)=angles';omega(k,:)=(E*rates)';alpha(k,:)=(E1*rates+E*accelerations)';
end
end
