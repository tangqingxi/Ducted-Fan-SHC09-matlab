function [measurement,sensor] = ca_sensor_step(omega,delta_hat,noise,sensor,cfg)
% 输入仅为物理角速度对应的传感器信号和模型舵角，不接收真实角加速度或外部扰动。
sensor.count=sensor.count+1;
width=size(sensor.rate_buffer,2);
slot=mod(sensor.count-1,width)+1;
sensor.rate_buffer(:,slot)=omega(:)+noise(:);
sensor.delta_buffer(:,slot)=delta_hat(:);
delayed_index=max(1,sensor.count-sensor.delay_samples);
delayed_slot=mod(delayed_index-1,width)+1;
rate=sensor.rate_buffer(:,delayed_slot);
delta=sensor.delta_buffer(:,delayed_slot);
measurement.delayed_raw_omega=rate;
if ~isempty(sensor.h3), [rate,sensor.h3]=ca_biquad_step(rate,sensor.h3); end
if ~isempty(sensor.notch), [rate,sensor.notch]=ca_biquad_step(rate,sensor.notch); end
% 初始一拍采用静止历史；随后严格执行图8中的后向差分及z的负一次延迟。
derivative=(rate-sensor.previous_omega)*cfg.sample_hz;
[measurement.alpha,sensor.h1]=ca_biquad_step(sensor.previous_derivative,sensor.h1);
[measurement.delta_feedback,sensor.h2]=ca_biquad_step(sensor.previous_delta,sensor.h2);
measurement.omega=rate;
measurement.derivative=derivative;
sensor.previous_omega=rate;
sensor.previous_derivative=derivative;
sensor.previous_delta=delta;
end
