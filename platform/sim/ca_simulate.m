function log = ca_simulate(model, cfg, ref, method, experiment, runtime)
% 公共仿真调度器：连接传感器、控制器、分配器、执行器和物理对象。
% 五种分配器使用相同参考、控制器、真实执行器和刚体动力学。
n = numel(ref.time_s);
if ~isfield(ref,'position_ned_m'), ref.position_ned_m=repmat(cfg.position_reference_ned_m(:)',n,1); end
if nargin<5, experiment=ca_prepare_experiment(cfg,ref.time_s); end
assert(isequal(experiment.time_s,ref.time_s),'实验随机序列与参考时钟不一致。');
if nargin<6,runtime=shc09_runtime(cfg);end
bus=runtime.bus;scheduler=runtime.scheduler;
shc09_commander_module(bus,struct('mode',cfg.flight_mode,'armed',true),0);
sensor_cfg=shc09_module_params(cfg,"sensors");
position_cfg=shc09_module_params(cfg,"position");
attitude_cfg=shc09_module_params(cfg,"attitude");
rate_cfg=shc09_module_params(cfg,"rate");
cfg.disturbance_series=experiment.disturbance_series;
state=ca_plant_init(model,cfg);
allocator_cfg=ca_allocator_config(cfg);
allocation_model=effectiveness_for_model(model,allocator_cfg);
rotation=state.rotation; omega=state.omega; delta=state.delta;
delta_hat=delta;
held_command=delta;
motor_command=model.hover_motor_rad_s;
pending_command = held_command;
pending_source_time = 0;
pending_info = struct();
next_pwm_time = scheduler.next_pwm_time();
pwm_count = 0;
last_forecast = zeros(6,1);
time_tolerance = 1e-11;
filtered=string(cfg.measurement_mode)=="meng_filtered";
gyro_noise=experiment.gyro_noise_rad_s;
attitude_noise=experiment.attitude_noise_rad;
sensor=[];
if filtered
    sensor=ca_sensor_init(cfg,delta);
end
log.plant_model=model.plant_model;
log.allocator_config_fields=fieldnames(allocator_cfg);
log.flight_mode=cfg.flight_mode;
log.position_ned_m=zeros(n,3);
log.position_reference_ned_m=ref.position_ned_m;
log.allocation_held_command_rad=zeros(n,6);
log.velocity_ned_m_s=zeros(n,3);
log.motor_rad_s=zeros(n,1);
log.motor_command_rad_s=zeros(n,1);
log.exit_speed_m_s=zeros(n,1);
log.airspeed_body_m_s=zeros(n,3);
log.aero_torque_nm=zeros(n,3);
log.actual_torque_matrix=zeros(3,6,n);
log.effective_delta_rad=zeros(n,6);
log.vane_incremental_gain=zeros(n,6);
log.moment_model_error_nm=zeros(n,1);
log.table_extrapolated=false(n,1);
log.low_speed_regularized=false(n,1);
log.duct_angle_rad=zeros(n,1);
log.wing_angle_rad=zeros(n,1);
log.desired_euler_rad=zeros(n,3);
log.euler_rad = zeros(n,3);
log.omega_rad_s = zeros(n,3);
log.euler_error_rad = zeros(n,3);
log.rotation_error_rad = zeros(n,1);
log.rate_error_rad_s = zeros(n,3);
log.command_rad = zeros(n,6);
log.held_command_rad = zeros(n,6);
log.actual_delta_rad = zeros(n,6);
log.estimated_delta_rad = zeros(n,6);
log.v_h = zeros(n,3);
log.v_c = zeros(n,3);
log.disturbance_torque_nm = zeros(n,3);
log.gyro_noise_rad_s=gyro_noise;
log.attitude_noise_rad=attitude_noise;
log.measured_euler_rad=zeros(n,3);
log.measured_omega_rad_s=zeros(n,3);
log.omega_reference_rad_s=zeros(n,3);
log.alpha_reference_rad_s2=zeros(n,3);
log.measured_alpha_rad_s2=zeros(n,3);
log.true_alpha_rad_s2=zeros(n,3);
log.feedback_delta_rad=zeros(n,6);
log.lambda = NaN(n,1);
log.beta = NaN(n,1);
log.solve_time_s = zeros(n,1);
log.iterations = NaN(n,1);
log.solver_exitflag = zeros(n,1);
log.restore_exitflag=NaN(n,1);
log.restore_iterations=zeros(n,1);
log.restore_effect_error=NaN(n,1);
log.restore_solver_rescue=false(n,1);
log.native_residual = zeros(n,1);
log.common_residual = zeros(n,1);
log.priority_distance = zeros(n,1);
log.native_predicted_delta_rad = NaN(n,6);
log.common_predicted_delta_rad = NaN(n,6);
log.native_horizon_s = NaN(n,1);
log.native_prediction_available = false(n,1);
log.mode = zeros(n,1);
log.equality_error = zeros(n,1);
log.solver_rescue = false(n,1);
log.prediction_delay_s = zeros(n,1);
log.prediction_horizon_s = zeros(n,1);
log.actual_tau_s=zeros(n,6);
navigation_enabled=isfield(cfg,'navigation_mode') && string(cfg.navigation_mode)=="px4_ecl";
log.navigation_mode="ideal";
if navigation_enabled
    assert(isfield(experiment,'navigation'),'尚未生成导航传感器公共随机输入。');
    warm_started=tic;
    nav=ca_navigation_init(cfg,model,state,experiment.navigation);
    nav_cleanup=onCleanup(@()nav.bridge.close()); %#ok<NASGU>
    log.navigation_warmup_elapsed_s=toc(warm_started);
    log.navigation_initial_estimate=nav.warmup_estimate;
    log.navigation_mode="px4_ecl";
    fusion=struct('bridge',nav.bridge,'body_to_frd',nav.body_to_frd,'earth_rate_ned_rad_s',nav.earth_rate_ned_rad_s);
    log.estimated_position_ned_m=zeros(n,3); log.estimated_velocity_ned_m_s=zeros(n,3);
    log.estimated_gyro_bias_rad_s=zeros(n,3); log.estimated_accelerometer_bias_m_s2=zeros(n,3);
    log.navigation_position_variance_m2=zeros(n,3); log.navigation_health=zeros(n,6);
    log.navigation_new_aiding=false(n,3); log.raw_gyro_rad_s=zeros(n,3);
    log.raw_specific_force_m_s2=zeros(n,3); log.gnss_position_ned_m=NaN(n,3);
    log.navigation_step_time_s=zeros(n,1);
end
event_capacity = ceil(cfg.duration_s*cfg.pwm_hz)+3;
log.pwm_update_time_s = zeros(event_capacity,1);
log.pwm_source_time_s = zeros(event_capacity,1);
log.pwm_command_rad = zeros(event_capacity,6);
log.pwm_start_actual_delta_rad = zeros(event_capacity,6);
log.pwm_start_estimated_delta_rad = zeros(event_capacity,6);
log.pwm_end_predicted_delta_rad = zeros(event_capacity,6);
log.pwm_end_actual_delta_rad = NaN(event_capacity,6);
log.pwm_end_prediction_error_rad = NaN(event_capacity,6);
log.pwm_prediction_checked = false(event_capacity,1);
log.pwm_mode = zeros(event_capacity,1);
log.pwm_lambda = zeros(event_capacity,1);
started = tic;
for index = 1:n
    time_s = ref.time_s(index);
    disturbance=ca_disturbance_torque(time_s,cfg);
    physical=ca_plant_outputs(state,model,cfg,time_s);
    true_alpha=physical.alpha_rad_s2;
    log.actual_tau_s(index,:)=ca_true_actuator_tau(time_s,cfg)';
    if navigation_enabled
        nav_started=tic;
        [packet,observation,nav]=shc09_navigation_sensors(state,physical,nav,cfg,true);
        bus.publish('sensor_navigation',struct('packet',packet,'observation',observation),time_s);
        navigation=shc09_navigation_module(bus,fusion,time_s);nav.estimate=navigation;
        log.navigation_step_time_s(index)=toc(nav_started);
        assert(navigation.attitude_valid && navigation.position_valid && navigation.origin_valid ...
            && navigation.yaw_aligned && navigation.fault_code==0,'ca:NavigationInvalid', ...
            '官方EKF估计无效，已停止而非回退到真值。');
        control_position=navigation.position; control_velocity=navigation.velocity;
        measured_rotation=navigation.rotation;
        input_rate=navigation.rate_earth_corrected; input_noise=zeros(3,1);
        log.estimated_position_ned_m(index,:)=navigation.position';
        log.estimated_velocity_ned_m_s(index,:)=navigation.velocity';
        log.estimated_gyro_bias_rad_s(index,:)=navigation.gyro_bias';
        log.estimated_accelerometer_bias_m_s2(index,:)=navigation.accelerometer_bias';
        log.navigation_position_variance_m2(index,:)=navigation.position_variance';
        log.navigation_health(index,:)=[navigation.attitude_valid,navigation.position_valid,navigation.yaw_aligned, ...
            navigation.gps_active,navigation.origin_valid,navigation.fault_code];
        log.navigation_new_aiding(index,:)=navigation.new_aiding;
        log.raw_gyro_rad_s(index,:)=navigation.raw_gyro';
        log.raw_specific_force_m_s2(index,:)=navigation.raw_specific_force';
        log.gnss_position_ned_m(index,:)=navigation.gnss_position';
    else
        control_position=state.position; control_velocity=state.velocity;
        measured_rotation=rotation*ca_rotation_increment(attitude_noise(index,:)');
        input_rate=omega; input_noise=gyro_noise(index,:)';
        bus.publish('sensor_attitude',struct('rotation',measured_rotation),time_s);
        bus.publish('sensor_local_position',struct('position',control_position,'velocity',control_velocity),time_s);
        shc09_estimator_module(bus,time_s);
    end
    estimate=bus.latest('vehicle_attitude');measured_rotation=estimate.rotation;
    estimate=bus.latest('vehicle_local_position');control_position=estimate.position;control_velocity=estimate.velocity;
    % 真值仅在模拟器转换为显式测量；非理想模式不发布真实角加速度。
    if filtered
        imu=struct('rate',input_rate,'noise',input_noise);
    else
        imu=struct('rate',omega,'alpha',true_alpha);
    end
    bus.publish('sensor_imu',imu,time_s);
    bus.publish('estimated_actuator_state',struct('delta_hat',delta_hat),time_s);
    sensor=shc09_sensors_module(bus,sensor,sensor_cfg,time_s);
    measured=bus.latest('vehicle_angular_velocity');measured_omega=measured.omega;
    measured=bus.latest('vehicle_angular_acceleration');measured_alpha=measured.alpha;
    measured=bus.latest('filtered_actuator_state');feedback_delta=measured.delta_feedback;
    desired_rotation=ca_euler_rotation(ref.euler_rad(index,:)');
    desired_omega=ref.omega_body_rad_s(index,:)';
    desired_alpha=ref.alpha_body_rad_s2(index,:)';
    if string(cfg.flight_mode)=="position_hold"
        bus.publish('trajectory_setpoint',struct('position',ref.position_ned_m(index,:)','yaw',ref.euler_rad(index,3)),time_s);
        shc09_position_module(bus,model,position_cfg,time_s);
        setpoint=bus.latest('vehicle_attitude_setpoint');thrust=bus.latest('vehicle_thrust_setpoint');
        desired_rotation=setpoint.rotation;motor_command=thrust.motor_command;
        desired_omega=setpoint.omega;desired_alpha=setpoint.alpha;
    end
    true_relative_rotation=rotation'*desired_rotation;
    bus.publish('vehicle_attitude_setpoint',struct('rotation',desired_rotation,'omega',desired_omega,'alpha',desired_alpha),time_s);
    shc09_attitude_module(bus,attitude_cfg,time_s);
    rates=bus.latest('vehicle_rates_setpoint');omega_reference=rates.omega;alpha_reference=rates.alpha;
    shc09_rate_module(bus,struct('acceleration_matrix',model.acceleration_matrix),rate_cfg,time_s);
    demand=bus.latest('vehicle_torque_setpoint');v_h=demand.v_h;v_c=demand.v_c;
    timing = ca_pwm_timing(time_s,cfg,held_command);
    log.allocation_held_command_rad(index,:)=held_command';
    assert(abs(timing.delivery_time_s-next_pwm_time) < time_tolerance, 'PWM时钟与预测的下发时间不一致。');
    bus.publish('vehicle_torque_setpoint',struct('v_h',v_h,'v_c',v_c),time_s);
    bus.publish('vehicle_thrust_setpoint',struct('motor_command',motor_command),time_s);
    shc09_allocator_module(bus,method,allocation_model,allocator_cfg,timing,time_s);
    servos=bus.latest('actuator_servos');status=bus.latest('control_allocator_status');
    command=servos.command;info=status.info;
    pending_command = command;
    pending_source_time = time_s;
    pending_info = info;
    % 控制与PWM时间恰好重合时，约定先计算再下发；其余时刻只更新候选缓存。
    if next_pwm_time <= time_s+time_tolerance
        latch_pwm(next_pwm_time);
    end

    angles = ca_rotation_euler(rotation);
    assert(norm(ca_euler_rotation(angles)-rotation,'fro') < 1e-8, '欧拉角转换与旋转矩阵不一致。');
    desired_angles=ca_rotation_euler(desired_rotation);
    difference = angles-desired_angles;
    difference = atan2(sin(difference),cos(difference));
    log.position_ned_m(index,:)=state.position';
    log.velocity_ned_m_s(index,:)=state.velocity';
    log.motor_rad_s(index)=state.motor;
    log.motor_command_rad_s(index)=motor_command;
    log.exit_speed_m_s(index)=physical.exit_speed_m_s;
    log.airspeed_body_m_s(index,:)=physical.airspeed_body_m_s';
    log.aero_torque_nm(index,:)=physical.torque_body_nm';
    log.actual_torque_matrix(:,:,index)=physical.actual_torque_matrix;
    log.effective_delta_rad(index,:)=physical.effective_delta_rad';
    log.vane_incremental_gain(index,:)=physical.vane_incremental_gain';
    log.moment_model_error_nm(index)=norm(physical.actual_torque_matrix*physical.effective_delta_rad ...
        -model.torque_matrix*delta);
    log.table_extrapolated(index)=physical.table_extrapolated;
    log.low_speed_regularized(index)=physical.low_speed_regularized;
    log.duct_angle_rad(index)=physical.duct_angle_rad;
    log.wing_angle_rad(index)=physical.wing_angle_rad;
    log.desired_euler_rad(index,:)=desired_angles';
    log.euler_rad(index,:) = angles';
    log.omega_rad_s(index,:) = omega';
    log.euler_error_rad(index,:) = difference';
    log.rotation_error_rad(index) = acos(min(1,max(-1,(trace(true_relative_rotation)-1)/2)));
    log.rate_error_rad_s(index,:) = (omega-true_relative_rotation*desired_omega)';
    log.measured_euler_rad(index,:)=ca_rotation_euler(measured_rotation)';
    log.command_rad(index,:) = command';
    log.held_command_rad(index,:) = held_command';
    log.actual_delta_rad(index,:) = delta';
    log.estimated_delta_rad(index,:) = delta_hat';
    log.omega_reference_rad_s(index,:)=omega_reference';
    log.alpha_reference_rad_s2(index,:)=alpha_reference';
    log.v_h(index,:) = v_h';
    log.v_c(index,:) = v_c';
    log.disturbance_torque_nm(index,:) = disturbance';
    log.measured_omega_rad_s(index,:)=measured_omega';
    log.measured_alpha_rad_s2(index,:)=measured_alpha';
    log.true_alpha_rad_s2(index,:)=true_alpha';
    log.feedback_delta_rad(index,:)=feedback_delta';
    log.lambda(index) = info.lambda;
    log.beta(index) = info.beta;
    log.solve_time_s(index) = info.solve_time_s;
    log.iterations(index) = info.iterations;
    log.solver_exitflag(index) = info.exitflag;
    log.restore_exitflag(index)=info.restore_exitflag;
    log.restore_iterations(index)=info.restore_iterations;
    log.restore_effect_error(index)=info.restore_effect_error;
    log.restore_solver_rescue(index)=info.restore_solver_rescue;
    log.native_residual(index) = info.native_residual;
    log.common_residual(index) = info.common_residual;
    log.priority_distance(index) = info.priority_distance;
    log.native_predicted_delta_rad(index,:) = info.native_predicted_delta';
    log.common_predicted_delta_rad(index,:) = info.predicted_delta';
    log.native_horizon_s(index) = info.native_horizon_s;
    log.native_prediction_available(index) = info.native_prediction_available;
    log.mode(index) = info.mode;
    log.equality_error(index) = info.equality_error;
    log.solver_rescue(index) = info.solver_rescue;
    log.prediction_delay_s(index) = info.prediction_delay_s;
    log.prediction_horizon_s(index) = info.prediction_horizon_s;
    if index == n
        break;
    end

    % 在控制周期内部精确定位PWM事件，不能把333Hz近似成每两次或三次控制刷新。
    segment_start = time_s;
    interval_end = ref.time_s(index+1);
    while segment_start < interval_end-time_tolerance
        segment_end = scheduler.next_boundary(interval_end);
        duration_s = segment_end-segment_start;
        state=ca_plant_step(state,held_command,motor_command,duration_s,model,cfg,segment_start);
        delta_hat=shc09_actuator_estimator_module(bus,delta_hat,held_command,duration_s,allocator_cfg,segment_end);
        rotation=state.rotation; omega=state.omega; delta=state.delta;
        segment_start = segment_end;
        if segment_start < interval_end-time_tolerance
            latch_pwm(next_pwm_time);
        end
    end
    assert(all(isfinite(omega)) && norm(omega) < 100, '仿真出现非有限状态或异常角速度。');
end
log.elapsed_s = toc(started);
log.topic_log=runtime.logger.snapshot();
event_fields = {'pwm_update_time_s','pwm_source_time_s','pwm_command_rad', ...
    'pwm_start_actual_delta_rad','pwm_start_estimated_delta_rad','pwm_end_predicted_delta_rad', ...
    'pwm_end_actual_delta_rad','pwm_end_prediction_error_rad','pwm_prediction_checked','pwm_mode','pwm_lambda'};
for field_id = 1:numel(event_fields)
    field = event_fields{field_id};
    log.(field) = log.(field)(1:pwm_count,:);
end
log.name = char(method);
log.table_extrapolated_count=sum(log.table_extrapolated);
if log.table_extrapolated_count>0
    warning('ca:AeroTableExtrapolated','%s有%d/%d个控制采样点超出气动表迎角范围；详情见table_extrapolated与迎角日志。', ...
        method,log.table_extrapolated_count,n);
end

    function latch_pwm(event_time)
        % 此函数同时用于控制边界和控制周期内部，状态已推进到真实事件时刻。
        if pwm_count > 0
            log.pwm_end_actual_delta_rad(pwm_count,:) = delta';
            log.pwm_end_prediction_error_rad(pwm_count,:) = (delta-last_forecast)';
            log.pwm_prediction_checked(pwm_count) = true;
        end
        pwm_count = pwm_count+1;
        outputs=shc09_actuator_output_module(bus,event_time);
        assert(isequal(outputs.command,pending_command) && outputs.source_time_s==pending_source_time,'PWM候选缓存与topic不一致。');
        held_command = outputs.command;
        log.pwm_update_time_s(pwm_count) = event_time;
        log.pwm_source_time_s(pwm_count) = pending_source_time;
        log.pwm_command_rad(pwm_count,:) = held_command';
        log.pwm_start_actual_delta_rad(pwm_count,:) = delta';
        log.pwm_start_estimated_delta_rad(pwm_count,:) = delta_hat';
        log.pwm_end_predicted_delta_rad(pwm_count,:) = pending_info.predicted_delta';
        log.pwm_mode(pwm_count) = pending_info.mode;
        log.pwm_lambda(pwm_count) = pending_info.lambda;
        last_forecast = pending_info.predicted_delta;
        scheduler.advance_pwm();
        next_pwm_time = scheduler.next_pwm_time();
    end
end
