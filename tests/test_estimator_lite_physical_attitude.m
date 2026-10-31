function report = test_estimator_lite_physical_attitude(report)
% 实际六自由度闭环门禁；可传入已生成的验收记录重放断言，不重复试验。
if nargin<1
 c=ca_config();c.estimator_mode="lite";c.duration_s=12;c.roll_amplitude_deg=2;c.pitch_amplitude_deg=2;c.yaw_amplitude_deg=5;
 c.aero_low_speed_model="hold_90";c=ca_validate_config(c);m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);
 L=ca_simulate(m,c,r,"WLS",e);chosen=r.time_s<=10;
 a=rad2deg(L.estimated_attitude_error_rad(chosen));b=rad2deg(L.estimated_gyro_bias_error_rad_s(chosen,:));
 report=struct('attitude_rmse_deg',sqrt(mean(a.^2)),'attitude_peak_deg',max(a), ...
  'bias_rmse_max_axis_deg_s',max(sqrt(mean(b.^2,1))),'bias_final_max_axis_deg_s',max(abs(b(end,:))));
end
disp(report);
assert(report.attitude_rmse_deg<2 && report.attitude_peak_deg<5,'shc09:LitePhysicalAttitude','实际闭环姿态误差未达到门限。');
assert(report.bias_rmse_max_axis_deg_s<0.05 && report.bias_final_max_axis_deg_s<0.05, ...
 'shc09:LitePhysicalBias','实际闭环陀螺偏置未达到0.05度每秒门限，禁止真值补位或放宽验收。');
end
