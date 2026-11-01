function [cfg,model,ref,protocol]=ca_f8_protocol(scenario,seed)
% 从先验冻结文件构造F8配置；旧八字探索与旧悬停发布协议均不改写。
root=ca_setup();path=fullfile(root,'configs','f8_protocol_v1.json');protocol=jsondecode(fileread(path));
if nargin==0,cfg=protocol;model=[];ref=[];return;end
if nargin<2,seed=protocol.seeds(1);end
assert(ismember(seed,protocol.seeds),'正式F8只使用预先声明的保留种子。');
spec=protocol.scenarios(strcmp({protocol.scenarios.id},char(scenario)));assert(isscalar(spec),'未知F8场景。');
[cfg,model]=ca_figure8_search_protocol('F14_A2_Y20',seed,true);
cfg.position_gain=protocol.controller.position_gain(:);cfg.velocity_gain=protocol.controller.velocity_gain(:);
cfg.attitude_gain=protocol.controller.attitude_gain(:);cfg.rate_gain=protocol.controller.rate_gain(:);
cfg.f8_feedforward_enabled=true;cfg.f8_max_tilt_deg=protocol.controller.max_tilt_deg;
cfg.f8_max_thrust_fraction=protocol.controller.max_static_thrust_fraction;
ref=ca_f8_reference(cfg,spec,protocol);p=model.parameters;
thrust=model.mass_kg*vecnorm(ref.acceleration_ned_m_s2-[0,0,p.g],2,2);
tilt=rad2deg(atan2(vecnorm(ref.acceleration_ned_m_s2(:,1:2),2,2),p.g-ref.acceleration_ned_m_s2(:,3)));
preflight=struct('peak_horizontal_acceleration_m_s2',max(vecnorm(ref.acceleration_ned_m_s2(:,1:2),2,2)), ...
    'peak_speed_m_s',max(vecnorm(ref.velocity_ned_m_s,2,2)),'peak_reference_tilt_deg',max(tilt), ...
    'peak_static_thrust_fraction',max(thrust)/(p.Duct.k_T0*p.omega_m_max^2));
assert(preflight.peak_horizontal_acceleration_m_s2<=protocol.reference_preflight.max_horizontal_acceleration_m_s2, ...
    'F8参考超过预先规定的水平加速度余量。');
assert(preflight.peak_reference_tilt_deg<=protocol.reference_preflight.max_tilt_deg ...
    &&preflight.peak_static_thrust_fraction<=protocol.reference_preflight.max_static_thrust_fraction,'F8参考推力或倾角预检失败。');
protocol.scenario=spec;protocol.seed=seed;protocol.reference_preflight_result=preflight;
protocol.frozen_protocol_hash=allocation_comparison_hash(fileread(path));
protocol.reference_hash=allocation_comparison_hash(ref);protocol.engine_fingerprint=allocation_comparison_engine(root);
end
