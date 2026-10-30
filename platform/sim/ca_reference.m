function ref = ca_reference(cfg)
% 来源：code/shc09_attitude_reference.m；独立副本，原文件未修改。
% 生成带平滑包络和连续相位的姿态参考，避免阶跃和生硬频率切换。
dt = 1/cfg.sample_hz;
ref.time_s = (0:dt:cfg.duration_s)';
t = ref.time_s;
ref.position_ned_m=ca_stage_reference(t,cfg.position_reference_stages,cfg.position_transition_s,cfg.position_reference_ned_m);
n = numel(t);
frequency = cfg.yaw_frequency_stages(1, 2) * ones(n, 1);
frequency_dot = zeros(n, 1);
for stage = 2:size(cfg.yaw_frequency_stages, 1)
    start_time = cfg.yaw_frequency_stages(stage, 1);
    change = cfg.yaw_frequency_stages(stage, 2)-cfg.yaw_frequency_stages(stage-1, 2);
    [s, sd] = smooth_step((t-start_time)/cfg.frequency_transition_s);
    frequency = frequency+change*s;
    frequency_dot = frequency_dot+change*sd/cfg.frequency_transition_s;
end
[rise, rise_dot, rise_ddot] = smooth_step(t/cfg.envelope_ramp_s);
[fall, fall_dot, fall_ddot] = smooth_step((cfg.duration_s-t)/cfg.envelope_ramp_s);
rise_dot = rise_dot/cfg.envelope_ramp_s;
rise_ddot = rise_ddot/cfg.envelope_ramp_s^2;
fall_dot = -fall_dot/cfg.envelope_ramp_s;
fall_ddot = fall_ddot/cfg.envelope_ramp_s^2;
envelope = rise.*fall;
envelope_dot = rise_dot.*fall+rise.*fall_dot;
envelope_ddot = rise_ddot.*fall+2*rise_dot.*fall_dot+rise.*fall_ddot;
phases = [2*pi*cfg.roll_frequency_hz*t, ...
    2*pi*cfg.pitch_frequency_hz*t+pi/3, 2*pi*cumtrapz(t, frequency)];
phase_dot = [2*pi*cfg.roll_frequency_hz*ones(n,1), ...
    2*pi*cfg.pitch_frequency_hz*ones(n,1), 2*pi*frequency];
phase_ddot = [zeros(n,2), 2*pi*frequency_dot];
amplitudes = deg2rad([cfg.roll_amplitude_deg, cfg.pitch_amplitude_deg, cfg.yaw_amplitude_deg]);
ref.euler_rad = amplitudes.*(envelope.*sin(phases));
ref.euler_dot_rad_s = amplitudes.*(envelope_dot.*sin(phases)+envelope.*phase_dot.*cos(phases));
ref.euler_ddot_rad_s2 = amplitudes.*(envelope_ddot.*sin(phases) ...
    +2*envelope_dot.*phase_dot.*cos(phases)+envelope.*phase_ddot.*cos(phases) ...
    -envelope.*phase_dot.^2.*sin(phases));
ref.yaw_frequency_hz = frequency;
ref.omega_body_rad_s = zeros(n,3);
ref.alpha_body_rad_s2 = zeros(n,3);
for index = 1:n
    phi = ref.euler_rad(index,1);
    theta = ref.euler_rad(index,2);
    phi_dot = ref.euler_dot_rad_s(index,1);
    theta_dot = ref.euler_dot_rad_s(index,2);
    transform = [1,0,-sin(theta); 0,cos(phi),sin(phi)*cos(theta); ...
        0,-sin(phi),cos(phi)*cos(theta)];
    transform_dot = [0,0,-cos(theta)*theta_dot; ...
        0,-sin(phi)*phi_dot,cos(phi)*phi_dot*cos(theta)-sin(phi)*sin(theta)*theta_dot; ...
        0,-cos(phi)*phi_dot,-sin(phi)*phi_dot*cos(theta)-cos(phi)*sin(theta)*theta_dot];
    ref.omega_body_rad_s(index,:) = (transform*ref.euler_dot_rad_s(index,:)')';
    ref.alpha_body_rad_s2(index,:) = (transform*ref.euler_ddot_rad_s2(index,:)' ...
        +transform_dot*ref.euler_dot_rad_s(index,:)')';
end
end

function [value, first, second] = smooth_step(x)
% 五次平滑阶跃在端点的一阶和二阶导数均为零。
z = min(max(x,0),1);
value = 10*z.^3-15*z.^4+6*z.^5;
first = 30*z.^2-60*z.^3+30*z.^4;
second = 60*z-180*z.^2+120*z.^3;
outside = x <= 0 | x >= 1;
first(outside) = 0;
second(outside) = 0;
end
