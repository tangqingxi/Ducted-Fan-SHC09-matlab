function [cfg,model,ref,protocol]=ca_f8_pressure_protocol(scenario,seed,version)
% 独立压力预案只改变计划偏航；所选基线的位置、门槛、对象、五算法与控制参数保留。
if nargin<3,version=1;end
assert(ismember(version,[1,2]));root=ca_setup();pressure_text=fileread(fullfile(root,'configs',sprintf('f8_pressure_protocol_v%d.json',version)));
pressure=jsondecode(pressure_text);base_text=fileread(fullfile(root,'configs','f8_protocol_v1.json'));
assert(string(pressure.base_protocol_hash)==allocation_comparison_hash(base_text),'原F8协议发生变化，不能沿用压力预案。');
if nargin==0||isempty(scenario),cfg=pressure;model=[];ref=[];protocol=[];return;end
if nargin<2||isempty(seed),seed=pressure.development_seeds(1);end
assert(ismember(seed,[pressure.development_seeds(:);pressure.confirmation_seeds(:)]));
spec=pressure.candidates(strcmp({pressure.candidates.id},char(scenario)));assert(isscalar(spec),'未知偏航压力候选。');
[cfg,model,ref,protocol]=ca_f8_protocol(pressure.base_position_scenario,101);
for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"]
    cfg.(field)=cfg.(field)+seed-101;
end
phase=ref.phase_rad;A=protocol.scenario.north_amplitude_m;B=protocol.scenario.east_amplitude_m;
first=[A*cos(phase),2*B*cos(2*phase),zeros(size(phase))];
second=[-A*sin(phase),-4*B*sin(2*phase),zeros(size(phase))];denominator=sum(first.^2,2);
phase_rate=sum(first.*ref.velocity_ned_m_s,2)./denominator;
phase_acceleration=sum(first.*(ref.acceleration_ned_m_s2-second.*phase_rate.^2),2)./denominator;
% 时钟频率相对位置相位的倍率；仅消费已知参考，不读取或数值差分估计器。
h=protocol.scenario.period_s*spec.yaw_clock_frequency_hz;amplitude=deg2rad(spec.yaw_amplitude_deg);
yaw=amplitude*sin(h*phase);yaw_rate=amplitude*h*cos(h*phase).*phase_rate;
yaw_acceleration=amplitude*h*(cos(h*phase).*phase_acceleration-h*sin(h*phase).*phase_rate.^2);
[ref.rotation_ff,ref.omega_body_rad_s,ref.alpha_body_rad_s2,ref.euler_rad]=ca_f8_attitude_reference( ...
    ref.acceleration_ned_m_s2,ref.jerk_ned_m_s3,ref.snap_ned_m_s4,yaw,yaw_rate,yaw_acceleration,model.parameters.g);
ref.yaw_rate_rad_s=yaw_rate;ref.yaw_acceleration_rad_s2=yaw_acceleration;
protocol.protocol_id=pressure.protocol_id;protocol.base_protocol_hash=pressure.base_protocol_hash;
protocol.pressure_protocol_version=version;protocol.pressure_base_position_scenario=pressure.base_position_scenario;
protocol.frozen_protocol_hash=allocation_comparison_hash({base_text,pressure_text});protocol.seed=seed;
protocol.seeds=pressure.confirmation_seeds;protocol.methods=pressure.confirmation_methods;
protocol.analysis.example_seed=pressure.confirmation_seeds(1);protocol.scenario.id=spec.id;
protocol.scenario.yaw_fundamental_deg=0;protocol.scenario.yaw_third_harmonic_deg=0;
protocol.scenario.yaw_amplitude_deg=spec.yaw_amplitude_deg;protocol.scenario.yaw_clock_frequency_hz=spec.yaw_clock_frequency_hz;
protocol.reference_hash=allocation_comparison_hash(ref);
protocol.reference_preflight_result.peak_yaw_rate_deg_s=max(abs(rad2deg(yaw_rate)));
protocol.reference_preflight_result.peak_yaw_acceleration_deg_s2=max(abs(rad2deg(yaw_acceleration)));
protocol.reference_preflight_result.peak_body_rate_deg_s=max(vecnorm(rad2deg(ref.omega_body_rad_s),2,2));
protocol.reference_preflight_result.peak_body_acceleration_deg_s2=max(vecnorm(rad2deg(ref.alpha_body_rad_s2),2,2));
end
