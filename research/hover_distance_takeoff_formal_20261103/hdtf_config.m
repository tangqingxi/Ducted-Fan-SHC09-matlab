function [cfg,model,ref,plan,spec]=hdtf_config(seed)
% 独立55秒起飞场景，父控制器、估计器、对象、执行器和扰动幅频保持不变。
root=ca_setup();
for rel=["research/ppid_pindi","research/hover_distance","research/hover_distance_takeoff_20261103"]
    addpath(fullfile(root,rel));
end
p=jsondecode(fileread(fullfile(root,'research','hover_distance_takeoff_formal_20261103','protocol.json')));
assert(ismember(seed,p.seeds));[cfg,model,old_ref,plan,spec]=hd_config(seed,.85,280);
old_cfg=cfg;old_plan=plan;cfg.duration_s=p.duration_s;cfg.initial_position_ned_m=p.initial_position_ned_m(:);
cfg.disturbance_end_s=p.duration_s;t=(0:round(p.duration_s*cfg.sample_hz)+1)'/cfg.sample_hz;
up=smooth((t-p.disturbance_window_s(1))/p.disturbance_transition_s);
down=1-smooth((t-p.disturbance_window_s(2))/p.disturbance_transition_s);
torque=spec.roll_disturbance_amplitude_nm*up.*down.*sin(2*pi*p.roll_frequency_hz*(t-p.disturbance_window_s(1)));
cfg.disturbance_series=struct('time_s',t,'torque_nm',[torque,zeros(numel(t),2)]);
plan.hover_distance=p;plan.takeoff=p;
plan.controller.indi_output_filter_hz=p.indi_output_filter_hz;plan.controller.indi_input_filter_hz=p.indi_input_filter_hz;
ref=hdt_reference(p,cfg.sample_hz);ref=ca_reference_to_b(ref,model);
cfg=ca_validate_config(cfg);assert(isequaln(ca_model(cfg),model));
assert(string(ref.frame)=="b");
allowed={'duration_s','initial_position_ned_m','disturbance_end_s','disturbance_series'};
assert(isequaln(rmfield(cfg,allowed),rmfield(old_cfg,allowed)));
c=plan.controller;c.indi_output_filter_hz=old_plan.controller.indi_output_filter_hz;
c.indi_input_filter_hz=old_plan.controller.indi_input_filter_hz;assert(isequaln(c,old_plan.controller));
assert(isequaln(rmfield(plan,{'controller','hover_distance','takeoff'}),rmfield(old_plan,{'controller','hover_distance'})));
spec.takeoff=p;spec.duration_s=p.duration_s;spec.scenario=p.id;spec.main_window_s=p.main_window_s;
spec.recovery_window_s=p.recovery_window_s;spec.pwm_buffer_capacity=ceil(p.duration_s*cfg.pwm_hz)+2;
spec.expected_pwm_events=p.duration_s*cfg.pwm_hz+1;
q=ref.time_s>=15&ref.time_s<27;old_t=ref.time_s(q)-5;
disturbance_error=max(abs(interp1(old_cfg.disturbance_series.time_s,old_cfg.disturbance_series.torque_nm,old_t)-cfg.disturbance_series.torque_nm(find(q),:)),[],'all');
yaw_rate_error=max(abs(ref.omega_body_rad_s(q,:)-interp1(old_ref.time_s,old_ref.omega_body_rad_s,old_t)),[],'all');
yaw_acceleration_error=max(abs(ref.alpha_body_rad_s2(q,:)-interp1(old_ref.time_s,old_ref.alpha_body_rad_s2,old_t)),[],'all');
assert(max([disturbance_error,yaw_rate_error,yaw_acceleration_error])<1e-10);
spec.phase_translation_check=struct('shift_s',5,'disturbance_max_error_nm',disturbance_error, ...
    'yaw_rate_max_error_rad_s',yaw_rate_error,'yaw_acceleration_max_error_rad_s2',yaw_acceleration_error);
assert(numel(ref.time_s)==44001&&ref.time_s(end)==55&&spec.expected_pwm_events==18316);
end

function s=smooth(u)
% 五次包络与原40秒工况相同，仅平移时刻。
u=min(1,max(0,u));s=10*u.^3-15*u.^4+6*u.^5;
end
