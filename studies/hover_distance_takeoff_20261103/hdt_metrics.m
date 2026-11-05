function [m,checks]=hdt_metrics(L,cfg,model,ref,plan)
% 只读本条日志；以800Hz状态评分、400Hz分配事件计时，不回写旧审计。
t=L.time_s;q=t>=12&t<24;qc=q&L.control_updated;n=sum(qc);
assert(numel(t)==40001&&t(end)==50&&isequal(t,ref.time_s));
assert(isequal(find(L.control_updated),(1:2:40001)')&&numel(L.pwm_time)==16651);
assert(sum(L.estimator_updated)==5001&&sum(L.gnss_fresh)==250);
assert(max(abs(L.pwm_time-(0:16650)'/333))<1e-10);
assert(~L.truth_feedback&&~any(ismember(string(L.control_interface_fields),["truth","state","actual_delta"])));
expected=L.gamma_ff+(L.omega_sp-L.measured_omega).*plan.controller.rate_gain(:)';
formula_error=max(abs(L.v_c(L.control_updated,:)-expected(L.control_updated,:)),[],'all');assert(formula_error<1e-10);
assert(max(abs(L.command),[],'all')<=model.command_upper(1)+cfg.constraint_tolerance);
assert(max(abs(rad2deg(L.actual_delta)),[],'all')<=40+1e-7);
assert(max(abs(rad2deg(diff(L.actual_delta))*800),[],'all')<=600+1e-6);
% 仿真器未记录电机指令，离线重放原控制函数并核对日志信号；不调用对象积分。
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
lambda=L.lambda(qc&normal);[minimum,j]=min(lambda);normal_times=t(qc&normal);
if isempty(minimum),minimum=NaN;minimum_time=NaN;else,minimum_time=normal_times(j);end
vane_rate=rad2deg(diff(L.actual_delta))*800;whole_travel=sum(abs(rad2deg(diff(L.actual_delta))),'all');
ix=find(q);main_changes=rad2deg(diff(L.actual_delta(ix,:)));pwm_step=rad2deg(diff(L.pwm_command));
at8=round(8*800)+1;settle=t>=10&t<12;g=plan.takeoff.engineering_takeoff_check;
m=struct('method',"PCA_PREDICTIVE",'seed',501,'duration_s',t(end),'state_samples',numel(t), ...
    'main_samples',sum(q),'main_control_samples',n,'completed_50s',true,'estimator_valid_all',true, ...
    'finite_states',all(isfinite([L.position,L.velocity,L.euler,L.omega,L.estimated_position,L.estimated_velocity]),'all'), ...
    'aero_domain_failures',sum(L.aero_outside),'lambda_scaled_duty',mean(active(qc)), ...
    'lambda_scaled_duration_s',sum(active(qc))/400,'lambda_longest_episode_s',longest(active(qc))/400, ...
    'normal_lambda_min',minimum,'lambda_min_time_s',minimum_time,'mode1_duty',mean(L.mode(qc)==1), ...
    'mode1_duration_s',sum(L.mode(qc)==1)/400,'mode2_duty',mean(L.mode(qc)==2), ...
    'actual_tilt_peak_deg',max(tilt),'command_tilt_peak_deg',max(command_tilt), ...
    'thrust_fraction_peak',max(thrust_fraction),'thrust_saturation_events',sum(thrust_fraction>=plan.controller.thrust_fraction_limit-1e-9), ...
    'tilt_saturation_samples',sum(tilt>=plan.controller.tilt_limit_deg-1e-6|command_tilt>=plan.controller.tilt_limit_deg-1e-6), ...
    'actual_servo_rate_rms_deg_s',sqrt(mean(vane_rate.^2,'all')),'actual_servo_travel_deg',whole_travel, ...
    'main_servo_rate_rms_deg_s',sqrt(mean((main_changes*800).^2,'all')), ...
    'main_servo_travel_deg',sum(abs(main_changes),'all'),'pwm_step_rms_deg',sqrt(mean(pwm_step.^2,'all')));
for domain=["estimated","true"]
    if domain=="estimated",pos=L.estimated_position;vel=L.estimated_velocity;roll=L.estimated_euler(:,1);rate=L.measured_omega(:,3);
    else,pos=L.position;vel=L.velocity;roll=L.euler(:,1);rate=L.omega(:,3);end
    prefix=char(domain+"_");error=pos-ref.position_ned_m;distance=vecnorm(error(:,1:2),2,2);
    m.([prefix,'horizontal_rmse_m'])=sqrt(mean(distance(q).^2));m.([prefix,'horizontal_peak_m'])=max(distance(q));
    m.([prefix,'roll_rmse_deg'])=rad2deg(sqrt(mean(roll(q).^2)));
    m.([prefix,'yaw_rate_rmse_deg_s'])=rad2deg(sqrt(mean((rate(q)-ref.omega_body_rad_s(q,3)).^2)));
    m.([prefix,'altitude_at_8s_m'])=-pos(at8,3);m.([prefix,'vertical_speed_at_8s_m_s'])=vel(at8,3);
    m.([prefix,'settle_height_rmse_m'])=sqrt(mean((pos(settle,3)+10).^2));
    m.([prefix,'settle_vertical_speed_rmse_m_s'])=sqrt(mean(vel(settle,3).^2));
    m.([prefix,'takeoff_reached'])=abs(pos(at8,3)+10)<=g.height_error_at_8s_max_m;
    m.([prefix,'settled_before_12s'])=m.([prefix,'settle_height_rmse_m'])<=g.height_rmse_max_m ...
        &&m.([prefix,'settle_vertical_speed_rmse_m_s'])<=g.vertical_speed_rmse_max_m_s;
end
m.no_divergence=m.finite_states&&max(vecnorm(L.position(:,1:2),2,2))<15&&max(abs(L.position(:,3)))<20;
m.precheck_passed=m.no_divergence&&m.aero_domain_failures==0&&m.thrust_saturation_events==0 ...
    &&m.tilt_saturation_samples==0&&m.estimated_takeoff_reached&&m.true_takeoff_reached ...
    &&m.estimated_settled_before_12s&&m.true_settled_before_12s;
checks=struct('truth_interface_checked',true,'all_estimator_assertions_passed',true,'maximum_control_formula_error',formula_error, ...
    'controller_replay_error',replay_error,'motor_source','Offline replay of unchanged controller; motor not logged by simulator.', ...
    'pwm_capacity',ceil(52*333)+2,'pwm_events',numel(L.pwm_time),'precheck_passed',m.precheck_passed);
end

function n=longest(active)
% 只用400Hz决策点的连续段计时。
e=diff([false;active(:);false]);n=max([0;find(e==-1)-find(e==1)]);
end
