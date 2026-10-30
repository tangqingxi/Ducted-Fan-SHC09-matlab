function log = shc09_simulate_attitude(model, cfg, ref, predictive)
% 两种分配器使用相同参考、控制器、真实执行器和刚体动力学。
n = numel(ref.time_s);
J = model.inertia;
C = model.torque_matrix;
B = model.acceleration_matrix;
rotation = eye(3);
omega = zeros(3,1);
delta = zeros(6,1);
delta_hat = zeros(6,1);
held_command = zeros(6,1);
pending_command = held_command;
pending_source_time = 0;
pending_info = struct();
next_pwm_index = 0;
next_pwm_time = cfg.pwm_phase_s;
pwm_count = 0;
last_forecast = zeros(6,1);
time_tolerance = 1e-11;
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
log.lambda = zeros(n,1);
log.mode = zeros(n,1);
log.equality_error = zeros(n,1);
log.solver_rescue = false(n,1);
log.prediction_delay_s = zeros(n,1);
log.prediction_horizon_s = zeros(n,1);
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
    desired_rotation = euler_rotation(ref.euler_rad(index,:)');
    relative_rotation = rotation'*desired_rotation;
    desired_omega = ref.omega_body_rad_s(index,:)';
    desired_alpha = ref.alpha_body_rad_s2(index,:)';
    attitude_error = 0.5*vee(relative_rotation-relative_rotation');
    relative_dot = -skew(omega)*relative_rotation+relative_rotation*skew(desired_omega);
    attitude_error_dot = 0.5*vee(relative_dot-relative_dot');
    transported_omega = relative_rotation*desired_omega;
    omega_reference = transported_omega+cfg.attitude_gain(:).*attitude_error;
    alpha_reference = relative_dot*desired_omega+relative_rotation*desired_alpha ...
        +cfg.attitude_gain(:).*attitude_error_dot;

    % 这里的理想角加速度测量供两种方法共同使用；估计舵角由各自模型独立推进。
    measured_alpha = J \ (C*delta+cfg.disturbance_torque_nm(:)-cross(omega,J*omega));
    v_h = B*delta_hat-measured_alpha+alpha_reference;
    v_c = cfg.rate_gain(:).*(omega_reference-omega);
    timing = shc09_pwm_timing(time_s,cfg,held_command);
    assert(abs(timing.delivery_time_s-next_pwm_time) < time_tolerance, 'PWM时钟与预测的下发时间不一致。');
    [command, info] = shc09_predictive_allocator(v_h,v_c,B,delta_hat,model,cfg,predictive,timing);
    pending_command = command;
    pending_source_time = time_s;
    pending_info = info;
    % 控制与PWM时间恰好重合时，约定先计算再下发；其余时刻只更新候选缓存。
    if next_pwm_time <= time_s+time_tolerance
        latch_pwm(next_pwm_time);
    end

    angles = rotation_euler(rotation);
    assert(norm(euler_rotation(angles)-rotation,'fro') < 1e-8, '欧拉角转换与旋转矩阵不一致。');
    difference = angles-ref.euler_rad(index,:)';
    difference = atan2(sin(difference),cos(difference));
    log.euler_rad(index,:) = angles';
    log.omega_rad_s(index,:) = omega';
    log.euler_error_rad(index,:) = difference';
    log.rotation_error_rad(index) = acos(min(1,max(-1,(trace(relative_rotation)-1)/2)));
    log.rate_error_rad_s(index,:) = (omega-transported_omega)';
    log.command_rad(index,:) = command';
    log.held_command_rad(index,:) = held_command';
    log.actual_delta_rad(index,:) = delta';
    log.estimated_delta_rad(index,:) = delta_hat';
    log.v_h(index,:) = v_h';
    log.v_c(index,:) = v_c';
    log.lambda(index) = info.lambda;
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
        segment_end = min(interval_end,next_pwm_time);
        duration_s = segment_end-segment_start;
        [rotation,omega,delta,delta_hat] = advance_segment( ...
            rotation,omega,delta,delta_hat,held_command,duration_s,model,cfg);
        segment_start = segment_end;
        if segment_start < interval_end-time_tolerance
            latch_pwm(next_pwm_time);
        end
    end
    assert(all(isfinite(omega)) && norm(omega) < 100, '仿真出现非有限状态或异常角速度。');
end
log.elapsed_s = toc(started);
event_fields = {'pwm_update_time_s','pwm_source_time_s','pwm_command_rad', ...
    'pwm_start_actual_delta_rad','pwm_start_estimated_delta_rad','pwm_end_predicted_delta_rad', ...
    'pwm_end_actual_delta_rad','pwm_end_prediction_error_rad','pwm_prediction_checked','pwm_mode','pwm_lambda'};
for field_id = 1:numel(event_fields)
    field = event_fields{field_id};
    log.(field) = log.(field)(1:pwm_count,:);
end
if predictive
    log.name = '响应预测方法';
else
    log.name = '原 PCA';
end

    function latch_pwm(event_time)
        % 此函数同时用于控制边界和控制周期内部，状态已推进到真实事件时刻。
        if pwm_count > 0
            log.pwm_end_actual_delta_rad(pwm_count,:) = delta';
            log.pwm_end_prediction_error_rad(pwm_count,:) = (delta-last_forecast)';
            log.pwm_prediction_checked(pwm_count) = true;
        end
        pwm_count = pwm_count+1;
        held_command = pending_command;
        log.pwm_update_time_s(pwm_count) = event_time;
        log.pwm_source_time_s(pwm_count) = pending_source_time;
        log.pwm_command_rad(pwm_count,:) = held_command';
        log.pwm_start_actual_delta_rad(pwm_count,:) = delta';
        log.pwm_start_estimated_delta_rad(pwm_count,:) = delta_hat';
        log.pwm_end_predicted_delta_rad(pwm_count,:) = pending_info.predicted_delta';
        log.pwm_mode(pwm_count) = pending_info.mode;
        log.pwm_lambda(pwm_count) = pending_info.lambda;
        last_forecast = pending_info.predicted_delta;
        next_pwm_index = next_pwm_index+1;
        next_pwm_time = cfg.pwm_phase_s+next_pwm_index/cfg.pwm_hz;
    end
end

function [rotation,omega,delta,delta_hat] = advance_segment(rotation,omega,delta,delta_hat,held,duration_s,model,cfg)
% 真实舵机和估计器共同使用已经下发的保持指令，估计器不读取真实舵角。
J = model.inertia;
C = model.torque_matrix;
rate = deg2rad(cfg.rate_limit_deg_s);
delta_mid = shc09_actuator_step(delta,held,cfg.tau_actual_s,duration_s/2,rate);
delta_next = shc09_actuator_step(delta,held,cfg.tau_actual_s,duration_s,rate);
delta_hat = shc09_actuator_step(delta_hat,held,cfg.tau_model_s,duration_s,rate);
alpha_start = J \ (C*delta+cfg.disturbance_torque_nm(:)-cross(omega,J*omega));
omega_mid = omega+0.5*duration_s*alpha_start;
alpha_mid = J \ (C*delta_mid+cfg.disturbance_torque_nm(:)-cross(omega_mid,J*omega_mid));
rotation = rotation*rotation_increment((omega+0.5*duration_s*alpha_mid)*duration_s);
omega = omega+duration_s*alpha_mid;
delta = delta_next;
end

function matrix = skew(vector)
matrix = [0,-vector(3),vector(2); vector(3),0,-vector(1); -vector(2),vector(1),0];
end

function vector = vee(matrix)
vector = [matrix(3,2); matrix(1,3); matrix(2,1)];
end

function rotation = rotation_increment(vector)
angle = norm(vector);
matrix = skew(vector);
if angle < 1e-8
    rotation = eye(3)+matrix+0.5*matrix*matrix;
else
    rotation = eye(3)+sin(angle)/angle*matrix+(1-cos(angle))/angle^2*(matrix*matrix);
end
end

function rotation = euler_rotation(angles)
phi = angles(1);
theta = angles(2);
psi = angles(3);
rotation = [cos(psi)*cos(theta), cos(psi)*sin(theta)*sin(phi)-sin(psi)*cos(phi), cos(psi)*sin(theta)*cos(phi)+sin(psi)*sin(phi); ...
    sin(psi)*cos(theta), sin(psi)*sin(theta)*sin(phi)+cos(psi)*cos(phi), sin(psi)*sin(theta)*cos(phi)-cos(psi)*sin(phi); ...
    -sin(theta), cos(theta)*sin(phi), cos(theta)*cos(phi)];
end

function angles = rotation_euler(rotation)
angles = [atan2(rotation(3,2),rotation(3,3)); asin(min(1,max(-1,-rotation(3,1)))); ...
    atan2(rotation(2,1),rotation(1,1))];
end
