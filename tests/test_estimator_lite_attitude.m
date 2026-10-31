function report = test_estimator_lite_attitude()
% 传感器级重力模型试验；不能代替实际物理闭环门禁，真值只用于测试评价。
c=ca_validate_config(ca_config());c.estimator_mode="lite";c.duration_s=10;
p=shc09_lite_params(c);warm=round(c.navigation_warmup_s*c.sample_hz);n=warm+8001;
noise=shc09_lite_random(c,n);last=[];
for repeat=1:2
 bus=Shc09Bus();s=[];memory=[];errors=zeros(8001,1);bias_errors=zeros(8001,3);previous=eye(3);
 for k=1:n
  t=(k-warm-1)/c.sample_hz;u=max(0,t);
  angles=deg2rad([2*sin(0.4*u);1.5*sin(0.6*u);5*sin(0.5*u)]);R=ca_euler_rotation(angles);
  D=previous'*R;omega=c.sample_hz*[D(3,2)-D(2,3);D(1,3)-D(3,1);D(2,1)-D(1,2)]/2;previous=R;
  x=struct('rotation',R,'omega',omega,'position',zeros(3,1),'velocity',zeros(3,1));
  [q,memory]=shc09_lite_sensors(x,struct('acceleration_ned_m_s2',zeros(3,1)),c,noise,k,memory);
  shc09_lite_publish(bus,q,t);s=shc09_estimator_lite_module(bus,s,p,t);
  if k>warm
   h=bus.latest('estimator_health');assert(h.valid);i=k-warm;
   errors(i)=acos(min(1,max(-1,(trace(R'*s.rotation)-1)/2)));
   bias_errors(i,:)=(s.bias-deg2rad(c.gyro_bias_deg_s(:))-noise.walk(k,:)')';
  end
 end
 assert(~bus.exists('sensor_attitude') && ~bus.exists('sensor_local_position') && ~bus.exists('plant_truth'));
 if repeat==1,last=s;else,assert(isequaln(s,last),'估计器不确定。');end
end
report=struct('attitude_rmse_deg',rad2deg(sqrt(mean(errors.^2))),'attitude_peak_deg',rad2deg(max(errors)), ...
 'bias_rmse_max_axis_deg_s',max(rad2deg(sqrt(mean(bias_errors.^2,1)))),'bias_final_max_axis_deg_s',max(abs(rad2deg(bias_errors(end,:)))));
disp(report);assert(report.attitude_rmse_deg<2 && report.attitude_peak_deg<5 && report.bias_rmse_max_axis_deg_s<0.05 && report.bias_final_max_axis_deg_s<0.05,'shc09:LiteConvergence','lite姿态/偏置未达到验收门限。');
end
