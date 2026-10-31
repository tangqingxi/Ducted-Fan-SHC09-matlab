function test_sensor_model()
% 检查独立流、带宽标定、偏置、延迟、采样与方法配对。
c=ca_validate_config(ca_config());c.estimator_mode="lite";c.duration_s=2;m=ca_model(c);
r=ca_reference(c);a=ca_prepare_experiment(c,r.time_s);b=ca_prepare_experiment(c,r.time_s);assert(isequaln(a,b));
x=ca_plant_init(m,c);p=ca_plant_outputs(x,m,c,0);c.feedback_noise_enabled=false;
noise=shc09_lite_random(c,numel(r.time_s));memory=[];counts=zeros(1,3);
for k=1:numel(r.time_s)
 [q,memory]=shc09_lite_sensors(x,p,c,noise,k,memory);
 assert(norm(q.imu.accel-(x.rotation'*(p.acceleration_ned_m_s2-[0;0;c.lite_gravity_m_s2])+c.accelerometer_bias_m_s2))<1e-12);
 counts=counts+[q.gnss.fresh,q.baro.fresh,q.mag.fresh];
 if q.gnss.fresh,assert(abs(q.gnss.source_time_s-((k-1)/c.sample_hz-c.gnss_delay_s))<1e-12);end
end
assert(isequal(counts,[10,99,100]));
c.feedback_noise_enabled=true;noise=shc09_lite_random(c,80000);
sigma=std(rad2deg(noise.gyro));expected=c.gyro_noise_density_dps_sqrtHz*sqrt(pi*c.gyro_lpf_hz/2);
assert(all(abs(sigma/expected-1)<0.03));
end
