function [cfg,model,ref,experiment,protocol,cases] = ca_mismatch_protocol(duration_s,load_fraction,protocol_mode)
% 固定参考、初态与随机流；主协议隔离舵效，旧阶跃协议仅作显式对照。
if nargin<3, protocol_mode="load_hold"; end
assert(isscalar(string(protocol_mode)) && ismember(string(protocol_mode),["load_hold","pilot_12s"]),'协议模式错误。');
if nargin<1 || isempty(duration_s)
    duration_s=20; if string(protocol_mode)=="pilot_12s", duration_s=12; end
end
if nargin<2, load_fraction=0.6; end
assert(isscalar(load_fraction) && isfinite(load_fraction) && load_fraction>=0.4 && load_fraction<=0.8,'负载比例须为百分之四十至八十。');
expected=20; if string(protocol_mode)=="pilot_12s", expected=12; end
assert(isscalar(duration_s) && ismember(duration_s,[2,expected]),'主协议二十秒、旧协议十二秒，烟雾测试均为两秒。');
cfg=ca_config(); cfg.duration_s=duration_s;
cfg.flight_mode="position_hold"; cfg.plant_model="shc09_6dof";
cfg.aero_extrapolation_policy="error"; cfg.aero_low_speed_model="hold_90";
cfg.navigation_mode="ideal"; cfg.tau_actual_s=0.03*ones(6,1); cfg.tau_model_s=0.03*ones(6,1);
cfg.actuator_tau_variation_enabled=false;
cfg.position_reference_ned_m=[0;0;-10]; cfg.initial_position_ned_m=cfg.position_reference_ned_m;
cfg.position_reference_stages=zeros(0,4); cfg.position_transition_s=0.15;
cfg.wls_axis_weights=[1;1;1000];
window=[6,16]; unload=16;
if string(protocol_mode)=="pilot_12s"
    cfg.position_reference_stages=[0,0,0,-10;4,0,2,-10;5.5,0,-2,-10;7,0,2,-10;8.5,0,-2,-10;10,0,0,-10];
    window=[4,10]; unload=10; cfg.wls_axis_weights=[1000;1000;1];
end
cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.wind_ned_m_s=zeros(3,1); cfg.external_force_ned_n=zeros(3,1);
cfg.disturbance_torque_nm=zeros(3,1); cfg.disturbance_amplitude_nm=zeros(3,1);
cfg.disturbance_bias_nm=zeros(3,1); cfg.random_moment_rms_nm=zeros(3,1);
cfg.disturbance_type="constant"; cfg.disturbance_start_s=0; cfg.disturbance_end_s=Inf;
cfg.disturbance_transition_s=0.5;
cfg.gyro_noise_seed=20261029; cfg.attitude_noise_seed=43001; cfg.disturbance_seed=24001;
cfg.show_figures=false; cfg.save_figures=false;
cfg=ca_validate_config(cfg); model=ca_model(cfg); C=model.torque_matrix; p=model.parameters;
[u,~,flag]=linprog(-C(3,:)',[],[],C(1:2,:),zeros(2,1),model.command_lower,model.command_upper, ...
    optimoptions('linprog','Display','none'));
assert(flag>0,'名义偏航能力标定失败。');
capacity=C(3,:)*u;
passive=-p.FanDir*p.Duct.k_Q0*model.hover_motor_rad_s^2+p.FanDir*p.k_sta*model.hover_exit_speed_m_s^2;
external_yaw=-load_fraction*capacity-passive;
cfg.disturbance_stages_nm=[0,0,0,0;2,0,0,external_yaw;unload,0,0,0];
cfg=ca_validate_config(cfg); ref=ca_reference(cfg); experiment=ca_prepare_experiment(cfg,ref.time_s);
if duration_s==2, window=[0,2]; end
protocol=struct('name',"mismatch_"+string(protocol_mode),'mode',string(protocol_mode),'duration_s',duration_s, ...
    'load_fraction',load_fraction,'yaw_capacity_nm',capacity,'external_yaw_nm',external_yaw, ...
    'evaluation_window_s',window,'position_stages',cfg.position_reference_stages,'load_s',2,'unload_s',unload, ...
    'gyro_noise_seed',cfg.gyro_noise_seed,'attitude_noise_seed',cfg.attitude_noise_seed, ...
    'disturbance_seed',cfg.disturbance_seed,'wls_axis_weights',cfg.wls_axis_weights, ...
    'mismatch_working_delta_rad',load_fraction*u);
cases=struct('id',{'M0','M1','M2','M2b','M3','M4'}, ...
    'description',{'中性基线','统一增益增加百分之二十','零空间探针','行空间失配','三号舵弱化','双曲正切饱和'}, ...
    'gains',{ones(6,1),1.2*ones(6,1),[1.2;0.8;1.2;0.8;1.2;0.8],[1.2;1;0.8;1;1.2;1],[1;1;0.7;1;1;1],ones(6,1)}, ...
    'mapping',{'linear','linear','linear','linear','linear','tanh'},'saturation_deg',{28,28,28,28,28,28});
end
