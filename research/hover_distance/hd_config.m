function [cfg,model,ref,plan,spec]=hd_config(seed,fraction,yaw_peak)
% 共用控制与测量配置保持原样，只覆写新工况的时长、参考及私有外扰。
root=ca_setup();[cfg,model,~,parent]=ppid_config(seed);
scenario=jsondecode(fileread(fullfile(root,'research','hover_distance','protocol.json')));
if nargin<2,fraction=scenario.roll_load_fraction;end
if nargin<3,yaw_peak=scenario.yaw_rate_peak_deg_s;end
assert(ismember(seed,scenario.seeds)&&ismember(fraction,[.75,.80,.85,.90])&&ismember(yaw_peak,[280,300]));
plan=parent;plan.hover_distance=scenario;cfg.duration_s=scenario.duration_s;
cfg.position_reference_ned_m=scenario.position_ned_m(:);cfg.initial_position_ned_m=scenario.position_ned_m(:);
cfg.position_reference_stages=zeros(0,4);cfg.disturbance_stages_nm=zeros(0,4);
cfg.disturbance_torque_nm=zeros(3,1);cfg.disturbance_amplitude_nm=zeros(3,1);cfg.disturbance_bias_nm=zeros(3,1);
cfg.random_moment_rms_nm=zeros(3,1);cfg.disturbance_start_s=0;cfg.disturbance_end_s=scenario.duration_s;
cfg.disturbance_type="random";
authority=ca_priority_direction_protocol(cfg,model,fraction,8);
capacity=authority.axis_capacity_nm(:);amplitude=fraction*capacity(1);
time=(0:round(cfg.duration_s*cfg.sample_hz)+1)'/cfg.sample_hz;
up=smooth((time-scenario.disturbance_window_s(1))/scenario.disturbance_transition_s);
down=1-smooth((time-scenario.disturbance_window_s(2))/scenario.disturbance_transition_s);
torque=amplitude*up.*down.*sin(2*pi*scenario.roll_frequency_hz*(time-scenario.disturbance_window_s(1)));
cfg.disturbance_series=struct('time_s',time,'torque_nm',[torque,zeros(numel(time),2)]);
cfg=ca_validate_config(cfg);assert(isequaln(ca_model(cfg),model));
ref=hd_reference(scenario,cfg.sample_hz,yaw_peak);
spec=struct('seed',seed,'roll_load_fraction',fraction,'yaw_rate_peak_deg_s',yaw_peak, ...
    'axis_capacity_nm',capacity,'roll_disturbance_amplitude_nm',amplitude, ...
    'disturbance_transport','Native random-series interpolation field carries a deterministic sinusoid, with no random moment draw.', ...
    'parent_controller',parent.controller,'parent_sensor_profile',parent.sensors.profile);
end

function w=smooth(z)
% 五次平滑包络，端点一阶、二阶导数为零。
z=min(1,max(0,z));w=10*z.^3-15*z.^4+6*z.^5;
end
