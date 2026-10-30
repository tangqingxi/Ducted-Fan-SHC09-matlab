function sensor = ca_sensor_init(cfg,initial_delta)
% 图8基础链路：角速度差分与一拍延迟后进H1，模型舵角一拍延迟后进H2。
if nargin<2, initial_delta=zeros(6,1); end
sensor.h1=ca_biquad('lowpass',cfg.filter_h1_hz,cfg.sample_hz,3);
sensor.h2=ca_biquad('lowpass',cfg.filter_h2_hz,cfg.sample_hz,6);
sensor.h3=[];
sensor.notch=[];
if cfg.gyro_prefilter_enabled
    sensor.h3=ca_biquad('lowpass',cfg.gyro_prefilter_hz,cfg.sample_hz,3);
end
if cfg.gyro_notch_enabled
    sensor.notch=ca_biquad('notch',cfg.gyro_notch_hz,cfg.sample_hz,3,cfg.gyro_notch_bandwidth_hz);
end
sensor.delay_samples=round(cfg.gyro_transport_delay_s*cfg.sample_hz);
sensor.rate_buffer=zeros(3,sensor.delay_samples+1);
sensor.delta_buffer=repmat(initial_delta(:),1,sensor.delay_samples+1);
sensor.count=0;
sensor.previous_omega=zeros(3,1);
sensor.previous_derivative=zeros(3,1);
sensor.previous_delta=initial_delta(:);
% 二阶转置直接型的直流稳态，保持配平舵角与历史滤波量一致。
sensor.h2.state=[(1-sensor.h2.b(1))*initial_delta(:)'; ...
    (sensor.h2.b(3)-sensor.h2.a(3))*initial_delta(:)'];
end
