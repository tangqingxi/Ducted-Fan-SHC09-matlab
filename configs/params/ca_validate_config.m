function cfg = ca_validate_config(cfg)
% 在运行和建立输出之前检查关键物理参数及方法选择。
cfg=ca_realism_defaults(cfg);
assert(isscalar(string(cfg.navigation_mode)) && ismember(string(cfg.navigation_mode),["ideal","px4_ecl"]),'未知导航模式。');
assert(isscalar(string(cfg.estimator_mode)) && ismember(string(cfg.estimator_mode),["ideal","lite","px4_ecl"]),'未知估计器模式。');
% 历史调用常从默认cfg覆盖navigation_mode，保留该ECL入口兼容性。
if string(cfg.navigation_mode)=="px4_ecl" && string(cfg.estimator_mode)=="ideal",cfg.estimator_mode="px4_ecl";end
cfg.navigation_mode="ideal";
if string(cfg.estimator_mode)=="px4_ecl",cfg.navigation_mode="px4_ecl";end
if string(cfg.estimator_mode)=="lite"
    assert(string(cfg.plant_model)=="shc09_6dof" && string(cfg.measurement_mode)=="meng_filtered",'lite需要六自由度及滤波测量链。');
end
for field=["gyro_noise_density_dps_sqrtHz","gyro_lpf_hz","lite_attitude_kp","lite_attitude_ki", ...
 "lite_position_tau_s","lite_velocity_tau_s","lite_baro_tau_s","lite_gnss_timeout_s","lite_max_innovation_rad","lite_gravity_m_s2"]
    assert(isscalar(cfg.(field)) && isfinite(cfg.(field)) && cfg.(field)>0,'估计器参数必须为正有限数。');
end
assert(isscalar(cfg.gyro_bias_walk_deg_s_sqrt_s) && isfinite(cfg.gyro_bias_walk_deg_s_sqrt_s) && cfg.gyro_bias_walk_deg_s_sqrt_s>=0,'随机游走参数错误。');
assert(cfg.gyro_lpf_hz<cfg.sample_hz/2 && numel(cfg.lite_magnetic_ned_gauss)==3 && all(isfinite(cfg.lite_magnetic_ned_gauss)) && norm(cfg.lite_magnetic_ned_gauss(1:2))>0,'传感器带宽或磁场错误。');
assert(isscalar(cfg.lite_seed) && cfg.lite_seed>=0 && cfg.lite_seed==fix(cfg.lite_seed) && cfg.lite_seed<2^32-8,'lite种子错误。');
% 历史配置不启用低速方向正则化，保持旧物理输出。
if ~isfield(cfg,'aero_low_speed_m_s'), cfg.aero_low_speed_m_s=1; end
if ~isfield(cfg,'aero_low_speed_model'), cfg.aero_low_speed_model="legacy"; end
assert(isnumeric(cfg.aero_low_speed_m_s) && isreal(cfg.aero_low_speed_m_s) ...
    && isscalar(cfg.aero_low_speed_m_s) && isfinite(cfg.aero_low_speed_m_s) ...
    && cfg.aero_low_speed_m_s>=0 && cfg.aero_low_speed_m_s<=2, ...
    'ca:AeroLowSpeed','低速阈值必须为零至二米每秒的有限标量。');
assert(isscalar(string(cfg.aero_low_speed_model)) && ismember(string(cfg.aero_low_speed_model), ...
    ["legacy","hold_90"]),'ca:AeroLowSpeed','未知低速气动模型。');
% 缺少新字段的历史配置保持中性舵效，不改变旧结果。
if ~isfield(cfg,'vane_gain_scale'), cfg.vane_gain_scale=ones(6,1); end
if ~isfield(cfg,'vane_deflection_map'), cfg.vane_deflection_map="linear"; end
if ~isfield(cfg,'vane_saturation_deg'), cfg.vane_saturation_deg=28; end
assert(isnumeric(cfg.vane_gain_scale) && isreal(cfg.vane_gain_scale) ...
    && isvector(cfg.vane_gain_scale) && numel(cfg.vane_gain_scale)==6 ...
    && all(isfinite(cfg.vane_gain_scale(:))) && all(cfg.vane_gain_scale(:)>0), ...
    'ca:VaneGain','真实舵效倍率必须为六个正有限数。');
cfg.vane_gain_scale=cfg.vane_gain_scale(:);
assert(isscalar(string(cfg.vane_deflection_map)) && ismember(string(cfg.vane_deflection_map), ...
    ["linear","tanh","stall"]),'ca:VaneMap','未知真实舵角效能映射。');
assert(isnumeric(cfg.vane_saturation_deg) && isreal(cfg.vane_saturation_deg) ...
    && isscalar(cfg.vane_saturation_deg) && isfinite(cfg.vane_saturation_deg) ...
    && cfg.vane_saturation_deg>=20 && cfg.vane_saturation_deg<=40, ...
    'ca:VaneAngle','真实舵效特征角必须位于二十至四十度。');
assert(isscalar(string(cfg.navigation_mode)) && ismember(string(cfg.navigation_mode),["ideal","px4_ecl"]),'未知导航模式。');
if ismember(string(cfg.estimator_mode),["lite","px4_ecl"])
    assert(string(cfg.plant_model)=="shc09_6dof" && string(cfg.measurement_mode)=="meng_filtered", ...
        '官方ECL导航仅用于六自由度和非理想IMU测量模式。');
    assert(isscalar(cfg.navigation_warmup_s) && cfg.navigation_warmup_s>=12 && isfinite(cfg.navigation_warmup_s), ...
        '应预留不少于12秒静止对准和GNSS健康检查。');
assert(isscalar(cfg.navigation_seed) && cfg.navigation_seed>=0 && cfg.navigation_seed==fix(cfg.navigation_seed) ...
    && cfg.navigation_seed<2^32-6,'导航随机种子错误。');
assert(numel(cfg.navigation_origin)==3 && all(isfinite(cfg.navigation_origin)) ...
    && abs(cfg.navigation_origin(1))<85 && abs(cfg.navigation_origin(2))<=180,'导航地理参考错误。');
for field=["gnss_hz","barometer_hz","magnetometer_hz"]
    stride=cfg.sample_hz/cfg.(field);
    assert(isscalar(stride) && isfinite(stride) && stride>=1 && abs(stride-round(stride))<1e-9,'导航采样率须整除控制采样率。');
end
for field=["gnss_delay_s","barometer_delay_s","magnetometer_delay_s"]
    samples=cfg.sample_hz*cfg.(field);
    assert(isscalar(samples) && isfinite(samples) && samples>=0 && abs(samples-round(samples))<1e-9,'导航延迟须为非负整数个控制采样。');
end
for field=["gnss_position_std_m","gnss_position_bias_m","accelerometer_bias_m_s2","gyro_bias_deg_s","magnetometer_bias_gauss"]
    assert(numel(cfg.(field))==3 && all(isfinite(cfg.(field))),'导航噪声或偏置向量错误。');
end
assert(all(cfg.gnss_position_std_m>0),'GNSS位置标准差必须为正。');
for field=["accelerometer_noise_std_m_s2","gnss_velocity_std_m_s","barometer_noise_std_m","magnetometer_noise_std_gauss"]
    assert(isscalar(cfg.(field)) && isfinite(cfg.(field)) && cfg.(field)>0,'导航噪声标准差必须为正有限标量。');
end
end
assert(isscalar(cfg.actuator_tau_variation_enabled) && ismember(cfg.actuator_tau_variation_enabled,[0,1]),'舵机时变参数开关错误。');
assert(isscalar(cfg.actuator_tau_variation_fraction) && isfinite(cfg.actuator_tau_variation_fraction) ...
    && cfg.actuator_tau_variation_fraction>=0 && cfg.actuator_tau_variation_fraction<1,'舵机时间常数变化比例错误。');
assert(numel(cfg.actuator_tau_variation_period_s)==6 && all(isfinite(cfg.actuator_tau_variation_period_s)) ...
    && all(cfg.actuator_tau_variation_period_s>0) && numel(cfg.actuator_tau_variation_phase_rad)==6 ...
    && all(isfinite(cfg.actuator_tau_variation_phase_rad)),'六舵机缓变周期或相位错误。');
% 旧结果配置没有恢复模式字段时，继续采用原恢复步骤。
if ~isfield(cfg,'predictive_restore_mode'), cfg.predictive_restore_mode="legacy_norm"; end
assert(isscalar(string(cfg.predictive_restore_mode)) && ismember(string(cfg.predictive_restore_mode), ...
    ["legacy_norm","minimum_change"]),'预测PCA恢复模式错误。');
assert(isscalar(string(cfg.plant_model)) && ismember(string(cfg.plant_model),["shc09_6dof","hover_linear"]),'未知物理模型。');
assert(isscalar(string(cfg.aero_extrapolation_policy)) && ismember(string(cfg.aero_extrapolation_policy),["record","error"]),'未知气动表外推策略。');
assert(isscalar(string(cfg.flight_mode)) && ismember(string(cfg.flight_mode),["attitude","position_hold"]),'未知飞行模式。');
assert(isscalar(string(cfg.position_attitude_mode)) && ismember(string(cfg.position_attitude_mode),["exact_yaw","legacy_projection"]),'位置姿态构造模式错误。');
assert(string(cfg.flight_mode)~="position_hold" || string(cfg.plant_model)=="shc09_6dof",'位置模式必须使用六自由度对象。');
assert(isscalar(cfg.motor_tau_s) && isfinite(cfg.motor_tau_s) && cfg.motor_tau_s>0,'电机时间常数必须为正有限数。');
for name=["wind_ned_m_s","external_force_ned_n","position_reference_ned_m","initial_position_ned_m","position_gain","velocity_gain"]
    value=cfg.(name);
    assert(numel(value)==3 && all(isfinite(value)),'风、力、位置和增益必须为三个有限数。');
    if contains(name,"gain"), assert(all(value>0),'位置外环增益必须为正。'); end
end
for name=["position_reference_stages","disturbance_stages_nm"]
    stages=cfg.(name);
    assert(size(stages,2)==4 && all(isfinite(stages),'all'),'分段参考必须为时间加三轴数值。');
    if ~isempty(stages)
        assert(stages(1,1)==0 && all(diff(stages(:,1))>0),'分段时钟必须从零开始并严格递增。');
    end
end
positive={'position_transition_s','disturbance_transition_s','sample_hz','pwm_hz','duration_s','rate_limit_deg_s','envelope_ramp_s', ...
    'frequency_transition_s','wls_gamma','wls_input_weight','max_iterations','constraint_tolerance'};
for k=1:numel(positive)
    value=cfg.(positive{k});
    assert(isscalar(value) && isfinite(value) && value>0,'配置%s必须为正有限标量。',positive{k});
end
assert(cfg.pwm_hz<=cfg.sample_hz,'PWM频率不能超过本平台的控制频率。');
assert(isscalar(cfg.pwm_phase_s) && isfinite(cfg.pwm_phase_s) ...
    && cfg.pwm_phase_s>=0 && cfg.pwm_phase_s<1/cfg.pwm_hz,'PWM相位须位于一个周期内。');
assert(abs(cfg.duration_s*cfg.sample_hz-round(cfg.duration_s*cfg.sample_hz))<1e-8,'仿真时长须对应整数个控制步。');
for name=["tau_actual_s","tau_model_s"]
    value=cfg.(name);
    if isscalar(value), value=repmat(value,6,1); end
    assert(numel(value)==6 && all(isfinite(value)) && all(value>0),'时间常数须包含六个正有限数。');
    cfg.(name)=value(:);
end
for name=["attitude_gain","rate_gain","wls_axis_weights"]
    value=cfg.(name);
    assert(numel(value)==3 && all(isfinite(value)) && all(value>0),'增益或权重须为三个正有限数。');
    cfg.(name)=value(:);
end
assert(numel(cfg.disturbance_torque_nm)==3 && all(isfinite(cfg.disturbance_torque_nm)),'扰动力矩须为三个有限数。');
assert(isscalar(string(cfg.disturbance_type)) && ismember(string(cfg.disturbance_type),["sin","constant","random"]),'未知扰动类型。');
assert(isscalar(cfg.disturbance_end_s) && ~isnan(cfg.disturbance_end_s) ...
    && cfg.disturbance_end_s>=cfg.disturbance_start_s,'扰动终止时刻须不早于开始时刻。');
assert(numel(cfg.random_moment_rms_nm)==3 && all(isfinite(cfg.random_moment_rms_nm)) ...
    && all(cfg.random_moment_rms_nm>=0),'随机力矩RMS须为三个非负有限数。');
assert(numel(cfg.random_moment_correlation_s)==3 && all(isfinite(cfg.random_moment_correlation_s)) ...
    && all(cfg.random_moment_correlation_s>0),'随机力矩相关时间须为三个正有限数。');
assert(isscalar(cfg.disturbance_start_s) && isfinite(cfg.disturbance_start_s) ...
    && cfg.disturbance_start_s>=0,'扰动开始时刻必须为非负有限数。');
for name=["disturbance_amplitude_nm","disturbance_frequency_hz","disturbance_bias_nm"]
    value=cfg.(name);
    assert(numel(value)==3 && all(isfinite(value)),'时变扰动参数必须为三个有限数。');
    if name~="disturbance_bias_nm", assert(all(value>=0),'扰动幅值和频率须为非负数。'); end
    cfg.(name)=value(:);
end
assert(isempty(cfg.dca_horizon_s) || (isscalar(cfg.dca_horizon_s) ...
    && isfinite(cfg.dca_horizon_s) && cfg.dca_horizon_s>0),'DCA预测步长必须为正有限标量。');
assert(isscalar(cfg.predictive_horizon_fraction) && isfinite(cfg.predictive_horizon_fraction) ...
    && cfg.predictive_horizon_fraction>0 && cfg.predictive_horizon_fraction<=1, ...
    '预测PCA的保持周期比例必须位于0至1之间。');
assert(ismember(string(cfg.measurement_mode),["ideal","meng_filtered"]),'未知测量模式。');
assert(isscalar(cfg.gyro_noise_std_deg_s) && isfinite(cfg.gyro_noise_std_deg_s) ...
    && cfg.gyro_noise_std_deg_s>=0,'陀螺仪噪声标准差必须为非负有限标量。');
assert(isscalar(cfg.gyro_noise_seed) && cfg.gyro_noise_seed>=0 ...
    && cfg.gyro_noise_seed==fix(cfg.gyro_noise_seed),'噪声种子必须为非负整数。');
assert(isscalar(cfg.feedback_noise_enabled) && ismember(cfg.feedback_noise_enabled,[0,1]),'噪声开关须为逻辑标量。');
assert(numel(cfg.attitude_noise_std_deg)==3 && all(isfinite(cfg.attitude_noise_std_deg)) ...
    && all(cfg.attitude_noise_std_deg>=0),'姿态噪声须为三个非负有限数。');
for name=["attitude_noise_seed","disturbance_seed"]
    seed=cfg.(name);
    assert(isscalar(seed) && isfinite(seed) && seed>=0 && seed==fix(seed) && seed<2^32,'随机种子须为32位非负整数。');
end
delay=cfg.gyro_transport_delay_s*cfg.sample_hz;
assert(isscalar(delay) && isfinite(delay) && delay>=0 && abs(delay-round(delay))<1e-9, ...
    '额外测量传输延迟须为非负整数个控制周期。');
frequencies=[cfg.filter_h1_hz,cfg.filter_h2_hz];
if cfg.gyro_prefilter_enabled, frequencies(end+1)=cfg.gyro_prefilter_hz; end
if cfg.gyro_notch_enabled
    frequencies(end+1)=cfg.gyro_notch_hz;
    assert(isscalar(cfg.gyro_notch_bandwidth_hz) && isfinite(cfg.gyro_notch_bandwidth_hz) ...
        && cfg.gyro_notch_bandwidth_hz>0,'陷波带宽必须为正有限数。');
end
assert(all(isfinite(frequencies)) && all(frequencies>0) && all(frequencies<cfg.sample_hz/2), ...
    '启用的滤波频率必须位于零至奈奎斯特频率之间。');
stages=cfg.yaw_frequency_stages;
assert(size(stages,2)==2 && ~isempty(stages) && stages(1,1)==0 ...
    && all(isfinite(stages),'all') && all(diff(stages(:,1))>0) && all(stages(:,2)>0),'偏航分段频率配置错误。');
cfg.methods=reshape(string(cfg.methods),1,[]);
registered=registry();valid=[registered.name];
assert(~isempty(cfg.methods) && all(ismember(cfg.methods,valid)) ...
    && numel(unique(cfg.methods))==numel(cfg.methods),'方法列表包含未知或重复项。');
assert(~isempty(regexp(cfg.output_tag,'^[A-Za-z0-9_-]+$','once')),'结果标签只能使用字母、数字、下划线和连字符。');
assert(~cfg.save_figures || cfg.save_results,'保存图片时须同时保存结果。');
assert(license('test','Optimization_Toolbox'),'需要Optimization Toolbox。');
end
