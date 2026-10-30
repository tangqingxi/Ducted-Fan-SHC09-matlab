function test_sensor_chain()
% 独立核对滤波频响、历史时刻、导数来源及两方法同噪声条件。
ca_setup();
cfg=ca_validate_config(ca_config());
f=ca_biquad('lowpass',8,cfg.sample_hz,3);
assert(max(abs(roots(f.a)))<1 && abs(sum(f.b)/sum(f.a)-1)<1e-12,'低通滤波器不稳定或直流增益错误。');
% 用模拟域在Tustin映射频率处的解析频响验证数值递推。
frequency=3;
t=(0:3999)'/cfg.sample_hz;
signal=sin(2*pi*frequency*t);
response=zeros(size(signal));
for k=1:numel(signal)
    [value,f]=ca_biquad_step(signal(k)*ones(3,1),f);
    response(k)=value(1);
end
selected=t>=2;
coeff=[sin(2*pi*frequency*t(selected)),cos(2*pi*frequency*t(selected))]\response(selected);
wa=2*cfg.sample_hz*tan(pi*frequency/cfg.sample_hz);
wc=2*pi*8;
expected=wc^2/(-wa^2+1i*sqrt(2)*wc*wa+wc^2);
assert(norm(coeff-[real(expected);imag(expected)])<1e-9,'滤波递推的幅相与解析Tustin频响不符。');
notch=ca_biquad('notch',58,cfg.sample_hz,3,20);
z=exp(-2i*atan(2*pi*58/(2*cfg.sample_hz)));
assert(abs(sum(notch.b.*[1,z,z^2])/sum(notch.a.*[1,z,z^2]))<1e-10,'陷波零点频率错误。');
% 相同输入的两条H1/H2链均含一拍历史，不允许H2误用未生效的候选指令。
sensor=ca_sensor_init(cfg);
for k=1:1000
    omega=[0.1;-0.2;0.3]*(k-1)/cfg.sample_hz;
    [measurement,sensor]=ca_sensor_step(omega,0.2*ones(6,1),zeros(3,1),sensor,cfg);
    if k==1
        assert(norm(measurement.alpha)==0 && norm(measurement.delta_feedback)==0,'历史链未保留一拍延迟。');
    end
end
assert(norm(measurement.alpha-[0.1;-0.2;0.3])<1e-8,'角速度差分与H1稳态估计错误。');
assert(norm(measurement.delta_feedback-0.2*ones(6,1))<1e-8,'H2舵角估计稳态错误。');
delayed=cfg;
delayed.gyro_transport_delay_s=2/cfg.sample_hz;
sensor=ca_sensor_init(delayed);
for k=1:8
    [measurement,sensor]=ca_sensor_step(k*ones(3,1),zeros(6,1),zeros(3,1),sensor,delayed);
    assert(all(measurement.delayed_raw_omega==max(1,k-2)),'额外传输延迟时钟错误。');
end
short=cfg;
short.duration_s=0.1;
short.envelope_ramp_s=0.025;
short.measurement_mode="meng_filtered";
short.roll_amplitude_deg=0;
short.pitch_amplitude_deg=0;
short.yaw_amplitude_deg=0;
model=ca_model(short);
ref=ca_reference(short);
first=ca_simulate(model,short,ref,"DCA");
second=ca_simulate(model,short,ref,"PCA_PREDICTIVE");
assert(isequal(first.gyro_noise_rad_s,second.gyro_noise_rad_s),'两方法噪声序列不一致。');
assert(norm(first.measured_alpha_rad_s2-first.true_alpha_rad_s2,'fro')>1e-5, ...
    '含噪滤波链错误地返回了真实角加速度。');
assert(norm(first.feedback_delta_rad-first.estimated_delta_rad,'fro')>1e-8, ...
    '补偿反馈错误地跳过了H2。');
checked=first.pwm_prediction_checked;
assert(max(abs(first.pwm_end_prediction_error_rad(checked,:)),[],'all')<1e-10, ...
    '传感器滤波错误地改变了执行机构模型的一致性。');
fprintf('传感器滤波频响、差分、一拍历史、额外延迟、同噪声及预测状态区分检查通过。\n');
end
