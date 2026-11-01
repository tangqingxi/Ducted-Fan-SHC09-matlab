function [cfg,model,ref,protocol] = ca_figure8_search_protocol(scenario,seed,velocity_aiding)
% 预先固定更快八字及平滑偏航；执行器动态失配单列，不改原M2b定义或控制器。
catalog=struct('id',{'F14_A2_Y0','F14_A2_Y20','F10p5_A2_Y20','F10p5_A2_Y35H3','F14_A1p5_Y10','F14_A1p5_Y20','F42_A4p5_Y20','F42_A6_Y30'}, ...
    'period_s',{14,14,10.5,10.5,14,14,42,42},'north_amplitude_m',{2,2,2,2,1.5,1.5,4.5,6}, ...
    'yaw_fundamental_deg',{0,20,20,35,10,20,20,30},'yaw_third_harmonic_deg',{0,0,0,8,0,0,0,0});
if nargin==0,cfg=catalog;model=[];ref=[];protocol=[];return;end
if nargin<2,seed=2;end
if nargin<3,velocity_aiding=false;end
selected=find(string({catalog.id})==string(scenario));assert(numel(selected)==1,'未知预设八字候选。');spec=catalog(selected);
[cfg,model,~,~,old,cases]=ca_mismatch_protocol(20,0.6,"load_hold");
cfg.duration_s=52;cfg.estimator_mode="lite";cfg.save_results=false;cfg.save_figures=false;cfg.show_figures=false;
cfg.lite_velocity_aiding_enabled=logical(velocity_aiding);
cfg.tau_actual_s=0.001*[24;27;30;33;36;40];cfg.tau_model_s=0.03*ones(6,1);cfg.actuator_tau_variation_enabled=false;
cfg.disturbance_stages_nm(end,1)=50;
item=cases(string({cases.id})=="M2b");cfg.vane_gain_scale=item.gains;cfg.vane_deflection_map="linear";cfg.vane_saturation_deg=item.saturation_deg;
for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"]
    cfg.(field)=cfg.(field)+seed-1;
end
cfg=ca_validate_config(cfg);assert(isequaln(ca_model(cfg),model),'私有真实参数不得进入名义分配模型。');
ref=ca_reference(cfg);t=ref.time_s;hover=6;ramp=2;finish=50;cruise=40;
u=t-hover;clock=zeros(size(t));speed=clock;acceleration=clock;
q=u>0&u<ramp;z=u(q)/ramp;
clock(q)=ramp*(2.5*z.^4-3*z.^5+z.^6);speed(q)=10*z.^3-15*z.^4+6*z.^5;
acceleration(q)=(30*z.^2-60*z.^3+30*z.^4)/ramp;
q=u>=ramp&u<=ramp+cruise;clock(q)=ramp/2+u(q)-ramp;speed(q)=1;
q=u>ramp+cruise&u<2*ramp+cruise;z=(u(q)-ramp-cruise)/ramp;
clock(q)=ramp/2+cruise+ramp*(z-2.5*z.^4+3*z.^5-z.^6);
speed(q)=1-(10*z.^3-15*z.^4+6*z.^5);acceleration(q)=-(30*z.^2-60*z.^3+30*z.^4)/ramp;
clock(u>=2*ramp+cruise)=42;
phase=2*pi*clock/spec.period_s;rate=2*pi*speed/spec.period_s;rate_dot=2*pi*acceleration/spec.period_s;
A=spec.north_amplitude_m;B=A/2;
ref.position_ned_m=[A*sin(phase),B*sin(2*phase),-10*ones(size(t))];
ref.velocity_ned_m_s=[A*cos(phase).*rate,2*B*cos(2*phase).*rate,zeros(size(t))];
ref.acceleration_ned_m_s2=[A*(cos(phase).*rate_dot-sin(phase).*rate.^2), ...
    2*B*(cos(2*phase).*rate_dot-2*sin(2*phase).*rate.^2),zeros(size(t))];
yaw1=deg2rad(spec.yaw_fundamental_deg);yaw3=deg2rad(spec.yaw_third_harmonic_deg);
yaw=yaw1*sin(phase)+yaw3*sin(3*phase);
yaw_dot=(yaw1*cos(phase)+3*yaw3*cos(3*phase)).*rate;
yaw_ddot=(yaw1*cos(phase)+3*yaw3*cos(3*phase)).*rate_dot-(yaw1*sin(phase)+9*yaw3*sin(3*phase)).*rate.^2;
ref.euler_rad=[zeros(size(t)),zeros(size(t)),yaw];
ref.euler_dot_rad_s=[zeros(size(t)),zeros(size(t)),yaw_dot];
ref.euler_ddot_rad_s2=[zeros(size(t)),zeros(size(t)),yaw_ddot];
ref.omega_body_rad_s=ref.euler_dot_rad_s;ref.alpha_body_rad_s2=ref.euler_ddot_rad_s2;
protocol=struct('scenario_id',string(spec.id),'base_case',"M2b",'case_id',"M2b_"+string(spec.id)+"_servo_mismatch", ...
    'duration_s',52,'period_s',spec.period_s,'amplitude_ned_m',[A,B,0],'cycles',42/spec.period_s, ...
    'hover_s',hover,'phase_ramp_s',ramp,'motion_end_s',finish,'evaluation_window_s',[6,50], ...
    'cruise_window_s',[8,48],'altitude_m',10,'yaw_fundamental_deg',spec.yaw_fundamental_deg, ...
    'yaw_third_harmonic_deg',spec.yaw_third_harmonic_deg,'load_fraction',0.6,'external_yaw_nm',old.external_yaw_nm, ...
    'gains',item.gains,'mapping',"linear",'tau_actual_s',cfg.tau_actual_s,'tau_model_s',cfg.tau_model_s, ...
    'actuator_parameters_calibrated',false,'actuator_parameter_role',"用户批准的未实测动态失配假设", ...
    'command_limit_deg',40,'rate_limit_deg_s',600,'reference_hash',allocation_comparison_hash(ref), ...
    'peak_horizontal_speed_m_s',max(vecnorm(ref.velocity_ned_m_s(:,1:2),2,2)), ...
    'peak_horizontal_acceleration_m_s2',max(vecnorm(ref.acceleration_ned_m_s2(:,1:2),2,2)), ...
    'peak_yaw_rate_deg_s',max(abs(rad2deg(yaw_dot))), ...
    'controller_feedforward_role',"位置环只接收位置和偏航；几何速度、加速度及偏航导数仅记录，不新增前馈", ...
    'seed',seed,'lite_velocity_aiding_enabled',logical(velocity_aiding),'engine_fingerprint',allocation_comparison_engine(ca_setup()));
end
