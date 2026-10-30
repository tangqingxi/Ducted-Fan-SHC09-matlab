function [cfg,model,ref,protocol] = ca_candidate_protocol(case_name,seed,load_fraction,simulation_overrides)
% 预先固定小规模工况，不按某个分配器的结果修改轨迹或物理参数。
if nargin<2, seed=20261029; end
if nargin<3, load_fraction=0.8; end
if nargin<4, simulation_overrides=struct(); end
assert(isscalar(load_fraction) && isfinite(load_fraction) && load_fraction>0 && load_fraction<1,'负载占用必须在零到一之间。');
cfg=ca_config(); cfg.gyro_noise_seed=seed;
for field=reshape(string(fieldnames(simulation_overrides)),1,[])
    assert(isfield(cfg,field),'未知候选仿真配置：%s',field); cfg.(field)=simulation_overrides.(field);
end
cfg.plant_model="shc09_6dof"; cfg.flight_mode="position_hold";
cfg.initial_position_ned_m=[0;0;-10]; cfg.position_reference_ned_m=cfg.initial_position_ned_m;
cfg.roll_amplitude_deg=0; cfg.pitch_amplitude_deg=0; cfg.yaw_amplitude_deg=0;
cfg.wls_axis_weights=ones(3,1); cfg.predictive_restore_mode="minimum_change";
cfg.disturbance_type="constant"; cfg.disturbance_torque_nm=zeros(3,1);
cfg.disturbance_amplitude_nm=zeros(3,1); cfg.disturbance_bias_nm=zeros(3,1);
cfg.disturbance_transition_s=0.75; cfg.show_figures=false; cfg.save_figures=false;
cfg=ca_validate_config(cfg); model=ca_model(cfg);
load_protocol=ca_priority_direction_protocol(cfg,model,load_fraction,10);
case_name=string(case_name);
if startsWith(case_name,"figure8_")
    period=8; if case_name=="figure8_T12", period=12; else, assert(case_name=="figure8_T8",'未知八字工况。'); end
    ramp=2; start=4; stop=start+2*period+ramp;
    cfg.duration_s=stop+4;
    cfg.disturbance_stages_nm=[0,0,0,0;2,load_protocol.external_nm(:,1)';stop,0,0,0];
    ref=ca_reference(cfg); s=ref.time_s-start;
    phase=2*pi/period*(smooth_integral(s,ramp)-smooth_integral(s-(stop-start-ramp),ramp));
    ref.position_ned_m=[2*sin(phase),sin(2*phase),-10*ones(size(phase))];
    protocol=struct('case_name',case_name,'kind',"figure8",'period_s',period,'amplitudes_m',[2,1], ...
        'task_window_s',[start,stop],'recovery_window_s',[stop+0.75,cfg.duration_s], ...
        'load_fraction',load_fraction,'phase_ramp_s',ramp);
else
    assert(case_name=="hover_turning",'未知定点工况。');
    cfg.duration_s=22;
    cfg.disturbance_stages_nm=[0,0,0,0;2,load_protocol.external_nm(:,1)'; ...
        6,load_protocol.external_nm(:,2)';10,load_protocol.external_nm(:,3)'; ...
        14,load_protocol.external_nm(:,1)';18,0,0,0];
    ref=ca_reference(cfg);
    protocol=struct('case_name',case_name,'kind',"hover",'period_s',NaN,'amplitudes_m',[0,0], ...
        'task_window_s',[4,18],'recovery_window_s',[18.75,22],'load_fraction',load_fraction,'phase_ramp_s',NaN);
end
cfg=ca_validate_config(cfg);
end
function value=smooth_integral(time,ramp)
% 五次平滑速度的积分使八字从静止进入并在两圈后平滑停下，几何路径保持不变。
z=min(1,max(0,time/ramp)); value=ramp*(2.5*z.^4-3*z.^5+z.^6);
after=time>=ramp; value(after)=time(after)-ramp/2;
end
