function [cfg,model,ref,plan,spec]=hdt_config()
% 仅在独立新变体中改变时长、初始位置、参考、扰动时间和已指定滤波。
root=ca_setup();p=jsondecode(fileread(fullfile(root,'research','hover_distance_takeoff_20261103','protocol.json')));
[cfg,model,~,plan,spec]=hd_config(501,.85,280);parent_cfg=cfg;parent_plan=plan;
cfg.duration_s=p.duration_s;cfg.initial_position_ned_m=p.initial_position_ned_m(:);
cfg.disturbance_end_s=p.duration_s;
t=(0:round(p.duration_s*cfg.sample_hz)+1)'/cfg.sample_hz;
up=smooth((t-p.disturbance_window_s(1))/p.disturbance_transition_s);
down=1-smooth((t-p.disturbance_window_s(2))/p.disturbance_transition_s);
torque=spec.roll_disturbance_amplitude_nm*up.*down.*sin(2*pi*p.roll_frequency_hz*(t-p.disturbance_window_s(1)));
cfg.disturbance_series=struct('time_s',t,'torque_nm',[torque,zeros(numel(t),2)]);
plan.hover_distance.duration_s=50;plan.hover_distance.id=p.id;
plan.hover_distance.disturbance_window_s=p.disturbance_window_s;
plan.hover_distance.main_window_s=p.main_window_s;plan.hover_distance.recovery_window_s=p.recovery_window_s;
plan.controller.indi_output_filter_hz=15;plan.controller.indi_input_filter_hz=15;
plan.takeoff=p;ref=hdt_reference(p,cfg.sample_hz);cfg=ca_validate_config(cfg);
assert(isequaln(ca_model(cfg),model));
allowed={'duration_s','initial_position_ned_m','disturbance_end_s','disturbance_series'};
assert(isequaln(rmfield(cfg,allowed),rmfield(parent_cfg,allowed)));
c=plan.controller;c.indi_output_filter_hz=parent_plan.controller.indi_output_filter_hz;
c.indi_input_filter_hz=parent_plan.controller.indi_input_filter_hz;assert(isequaln(c,parent_plan.controller));
spec.takeoff=p;spec.parent_controller=parent_plan.controller;spec.duration_s=50;
spec.scenario=p.id;spec.main_window_s=p.main_window_s;spec.recovery_window_s=p.recovery_window_s;
spec.pwm_buffer_capacity=ceil(52*333)+2;spec.expected_pwm_events=50*333+1;
assert(spec.expected_pwm_events<=spec.pwm_buffer_capacity&&numel(ref.time_s)==40001);
% 对照旧压力序列，主窗内外扰与偏航速率仅平移2秒。
[old_cfg,~,old_ref]=hd_config(501,.85,280);q=ref.time_s>=12&ref.time_s<24;
old_t=ref.time_s(q)-2;
assert(max(abs(interp1(old_cfg.disturbance_series.time_s,old_cfg.disturbance_series.torque_nm,old_t)-cfg.disturbance_series.torque_nm(find(q),:)),[],'all')<1e-10);
assert(max(abs(ref.omega_body_rad_s(q,:)-interp1(old_ref.time_s,old_ref.omega_body_rad_s,old_t)),[],'all')<1e-10);
end

function s=smooth(u)
% 端点速度和加速度连续的五次包络。
u=min(1,max(0,u));s=10*u.^3-15*u.^4+6*u.^5;
end
