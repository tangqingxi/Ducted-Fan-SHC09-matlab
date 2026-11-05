function [m,checks]=hdtf_metrics(L,cfg,model,ref,plan,seed)
% 按新协议窗口评价；原始弧度约束不放宽，真值仅用于独立评价。
p=plan.takeoff;t=L.time_s;q=t>=p.main_window_s(1)&t<p.main_window_s(2);qc=q&L.control_updated;
fs=cfg.sample_hz;control_hz=400;duration=t(end)-t(1);N=numel(t);
assert(N==44001&&t(end)==p.duration_s&&isequal(t,ref.time_s));
assert(isequal(find(L.control_updated),(1:2:N)')&&numel(L.pwm_time)==18316);
assert(sum(L.estimator_updated)==5501&&sum(L.gnss_fresh)==275);
assert(max(abs(L.pwm_time-(0:18315)'/cfg.pwm_hz))<1e-10);
assert(~L.truth_feedback&&~any(ismember(string(L.control_interface_fields),["truth","state","actual_delta"])));
expected=L.gamma_ff+(L.omega_sp-L.measured_omega).*plan.controller.rate_gain(:)';
formula_error=max(abs(L.v_c(L.control_updated,:)-expected(L.control_updated,:)),[],'all');assert(formula_error<1e-10);
command_excess=max([0;reshape(L.command-model.command_upper(:)',[],1);reshape(model.command_lower(:)'-L.command,[],1)]);
assert(command_excess<=cfg.constraint_tolerance,'hdtf:CommandBounds','原始1e-7rad指令容差核验失败。');
assert(max(abs(rad2deg(L.actual_delta)),[],'all')<=40+1e-7);
vane_rate=rad2deg(diff(L.actual_delta))*fs;assert(max(abs(vane_rate),[],'all')<=600+1e-6);
% 离线重放控制函数，仅恢复未记录的电机指令，不推进对象或估计器。
nominal=struct('B',model.acceleration_matrix,'mass',model.mass_kg,'gravity',model.parameters.g, ...
    'thrust_k',model.parameters.Duct.k_T0,'omega_max',model.parameters.omega_m_max,'omega_min',model.parameters.omega_m_min);
mem=[];indices=find(L.control_updated);motors=zeros(numel(indices),1);replay_error=0;
for j=1:numel(indices)
    k=indices(j);fb=struct('position',L.estimated_position(k,:)','velocity',L.estimated_velocity(k,:)', ...
        'rotation',ca_euler_rotation(L.estimated_euler(k,:)'),'omega',L.measured_omega(k,:)');
    r=struct('position',ref.position_ned_m(k,:)','velocity',ref.velocity_ned_m_s(k,:)', ...
        'acceleration',ref.acceleration_ned_m_s2(k,:)','yaw',ref.euler_rad(k,3), ...
        'rotation_ff',ref.rotation_ff(:,:,k),'omega_ff',ref.omega_body_rad_s(k,:)','gamma_ff',ref.alpha_body_rad_s2(k,:)');
    measurement=struct('delta_feedback',zeros(6,1),'alpha',L.measured_gamma(k,:)');
    [~,motors(j),mem,s]=ppid_control_step(fb,r,nominal,plan.controller,measurement,mem,j-1);
    replay_error=max(replay_error,max(abs([s.acceleration_sp'-L.acceleration_sp(k,:),s.omega_sp'-L.omega_sp(k,:)])));
end
assert(replay_error<1e-8);thrust_fraction=(motors/nominal.omega_max).^2;
tilt=acosd(min(1,max(-1,cos(L.euler(:,1)).*cos(L.euler(:,2)))));
command_tilt=acosd(min(1,max(-1,cos(L.attitude_command(:,1)).*cos(L.attitude_command(:,2)))));
normal=L.mode==0&isfinite(L.lambda);active=normal&L.lambda<1-1e-6;
ix=find(qc&normal);minimum=NaN;minimum_time=NaN;
if ~isempty(ix),[minimum,j]=min(L.lambda(ix));minimum_time=t(ix(j));end
changes=rad2deg(diff(L.actual_delta));main_step=t(2:end)>=p.main_window_s(1)&t(2:end)<p.main_window_s(2);
pwm_step=rad2deg(diff(L.pwm_command));pw=L.pwm_time(2:end)>=p.main_window_s(1)&L.pwm_time(2:end)<p.main_window_s(2);
settle=t>=p.engineering_takeoff_check.settling_window_s(1)&t<p.engineering_takeoff_check.settling_window_s(2);
at_takeoff=round(p.takeoff_s*fs)+1;g=p.engineering_takeoff_check;lambda_applicable=startsWith(string(L.name),"PCA");
m=struct('method',string(L.name),'seed',seed,'duration_s',duration,'state_samples',N,'main_samples',sum(q), ...
    'main_control_samples',sum(qc),'completed_55s',true,'estimator_valid_all',true, ...
    'finite_states',all(isfinite([L.position,L.velocity,L.euler,L.omega,L.estimated_position,L.estimated_velocity,L.estimated_euler,L.measured_omega]),'all'), ...
    'aero_domain_failures',sum(L.aero_outside),'lambda_applicable',lambda_applicable, ...
    'lambda_scaled_duty',mean(active(qc)),'lambda_scaled_duration_s',sum(active(qc))/control_hz, ...
    'lambda_longest_episode_s',longest(active(qc))/control_hz,'normal_lambda_min',minimum,'lambda_min_time_s',minimum_time, ...
    'mode1_duty',mean(L.mode(qc)==1),'high_priority_fallback_duration_s',sum(L.mode(qc)==1)/control_hz, ...
    'mode2_duty',mean(L.mode(qc)==2),'engineering_fallback_duration_s',sum(L.mode(qc)==2)/control_hz, ...
    'actual_tilt_peak_deg',max(tilt),'main_actual_tilt_peak_deg',max(tilt(q)),'command_tilt_peak_deg',max(command_tilt), ...
    'thrust_fraction_peak',max(thrust_fraction),'thrust_saturation_events',sum(thrust_fraction>=plan.controller.thrust_fraction_limit-1e-9), ...
    'tilt_saturation_samples',sum(tilt>=plan.controller.tilt_limit_deg-1e-6|command_tilt>=plan.controller.tilt_limit_deg-1e-6), ...
    'whole_servo_rate_rms_deg_s',sqrt(mean(vane_rate.^2,'all')),'whole_servo_travel_deg',sum(abs(changes),'all'), ...
    'main_servo_rate_rms_deg_s',sqrt(mean(vane_rate(main_step,:).^2,'all')), ...
    'main_servo_travel_deg',sum(abs(changes(main_step,:)),'all'), ...
    'main_pwm_step_rms_deg',sqrt(mean(pwm_step(pw,:).^2,'all')),'main_pwm_step_total_deg',sum(abs(pwm_step(pw,:)),'all'), ...
    'main_pwm_nonzero_step_events',sum(any(abs(pwm_step(pw,:))>1e-9,2)), ...
    'main_command_limit_occupancy',mean(abs(rad2deg(L.command(q,:)))>=39.9,'all'), ...
    'main_actual_limit_occupancy',mean(abs(rad2deg(L.actual_delta(q,:)))>=39.9,'all'), ...
    'main_actual_rate_limit_occupancy',mean(abs(vane_rate(main_step,:))>=599.9,'all'), ...
    'command_excess_rad',command_excess,'allocator_constraint_tolerance_rad',cfg.constraint_tolerance, ...
    'legacy_degree_check_would_pass',max(abs(rad2deg(L.command)),[],'all')<=40+1e-7, ...
    'pwm_events',numel(L.pwm_time),'ekf_rate_hz',L.ekf_rate_hz);
if ~lambda_applicable
    m.lambda_scaled_duty=NaN;m.lambda_scaled_duration_s=NaN;m.lambda_longest_episode_s=NaN;
    m.normal_lambda_min=NaN;m.lambda_min_time_s=NaN;
end
for domain=["estimated","true"]
    if domain=="estimated",pos=L.estimated_position;vel=L.estimated_velocity;roll=L.estimated_euler(:,1);rate=L.measured_omega(:,3);
    else,pos=L.position;vel=L.velocity;roll=L.euler(:,1);rate=L.omega(:,3);end
    prefix=char(domain+"_");error=pos-ref.position_ned_m;distance=vecnorm(error(:,1:2),2,2);
    m.([prefix,'horizontal_rmse_m'])=sqrt(mean(distance(q).^2));m.([prefix,'horizontal_peak_m'])=max(distance(q));
    m.([prefix,'roll_rmse_deg'])=rad2deg(sqrt(mean(roll(q).^2)));m.([prefix,'roll_peak_deg'])=rad2deg(max(abs(roll(q))));
    m.([prefix,'yaw_rate_rmse_deg_s'])=rad2deg(sqrt(mean((rate(q)-ref.omega_body_rad_s(q,3)).^2)));
    m.([prefix,'altitude_at_12s_m'])=-pos(at_takeoff,3);m.([prefix,'vertical_speed_at_12s_m_s'])=vel(at_takeoff,3);
    m.([prefix,'settle_height_rmse_m'])=sqrt(mean((pos(settle,3)-p.position_ned_m(3)).^2));
    m.([prefix,'settle_vertical_speed_rmse_m_s'])=sqrt(mean(vel(settle,3).^2));
    m.([prefix,'takeoff_reached'])=abs(pos(at_takeoff,3)-p.position_ned_m(3))<=g.height_error_at_takeoff_end_max_m;
    m.([prefix,'settled_before_15s'])=m.([prefix,'settle_height_rmse_m'])<=g.height_rmse_max_m ...
        &&m.([prefix,'settle_vertical_speed_rmse_m_s'])<=g.vertical_speed_rmse_max_m_s;
    recovery=find(t>=p.recovery_window_s(1)&t<p.recovery_window_s(2));rr=p.recovery;
    settled=distance(recovery)<=rr.position_radius_m&vecnorm(vel(recovery,1:2),2,2)<=rr.speed_radius_m_s ...
        &abs(rad2deg(roll(recovery)))<=rr.roll_radius_deg;
    edges=diff([false;settled;false]);starts=find(edges==1);lengths=find(edges==-1)-starts;k=find(lengths>=rr.hold_s*fs,1);
    entry=NaN;if ~isempty(k),entry=t(recovery(starts(k)))-p.recovery_window_s(1);end
    m.([prefix,'recovery_entry_s'])=entry;m.([prefix,'recovery_confirmed_s'])=entry+rr.hold_s;
    m.([prefix,'recovery_not_reached'])=isempty(k);m.([prefix,'recovery_horizontal_peak_m'])=max(distance(recovery));
    m.([prefix,'recovery_roll_peak_deg'])=rad2deg(max(abs(roll(recovery))));
    initial=error(recovery(1),1:2);overshoot=NaN;
    if norm(initial)>1e-6,overshoot=max(0,-min(error(recovery,1:2)*initial'/norm(initial)));end
    m.([prefix,'recovery_opposite_position_overshoot_m'])=overshoot;
    m.([prefix,'recovery_opposite_roll_overshoot_deg'])=rad2deg(max(0,-min(sign(roll(recovery(1)))*roll(recovery))));
end
m.no_divergence=m.finite_states&&max(vecnorm(L.position(:,1:2),2,2))<15&&max(abs(L.position(:,3)))<20&&max(vecnorm(L.omega,2,2))<100;
m.data_valid=m.no_divergence&&m.aero_domain_failures==0;
m.takeoff_feasible=m.data_valid&&m.thrust_saturation_events==0&&m.tilt_saturation_samples==0 ...
    &&m.estimated_takeoff_reached&&m.true_takeoff_reached&&m.estimated_settled_before_15s&&m.true_settled_before_15s;
m.precheck_passed=m.takeoff_feasible&&lambda_applicable&&m.lambda_scaled_duration_s>0;
checks=struct('truth_interface_checked',true,'all_estimator_assertions_passed',true,'maximum_control_formula_error',formula_error, ...
    'controller_replay_error',replay_error,'motor_source','Offline replay only; unchanged controller, no plant integration.', ...
    'pwm_capacity',ceil(ref.time_s(end)*cfg.pwm_hz)+2,'pwm_events',numel(L.pwm_time), ...
    'original_rad_tolerance',cfg.constraint_tolerance,'command_excess_rad',command_excess, ...
    'command_bounds_passed',command_excess<=cfg.constraint_tolerance,'data_valid',m.data_valid,'precheck_passed',m.precheck_passed);
end

function n=longest(active)
% 仅在400Hz分配决策点计连续缩放时间。
e=diff([false;active(:);false]);n=max([0;find(e==-1)-find(e==1)]);
end
