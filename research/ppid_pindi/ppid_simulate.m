function L=ppid_simulate(cfg,model,ref,method,experiment,plan)
% 新研究多速率仿真器；物理真值只用于传感器生成、对象积分及离线日志。
[nav,bus,fusion]=ppid_estimator_init(cfg,model,plan,experiment.navigation);
cleanup=onCleanup(@()nav.bridge.close()); %#ok<NASGU>
% 起飞前用估计状态绑定局部任务坐标；全程固定，禁止事后真值拟合或动态重定中心。
navigation_origin_offset=nav.estimate.position-ref.position_ned_m(1,:)';
n=numel(ref.time_s);state=ca_plant_init(model,cfg);scheduler=Shc09Scheduler(800,333,0);
nominal=struct('B',model.acceleration_matrix,'mass',model.mass_kg,'gravity',model.parameters.g, ...
    'thrust_k',model.parameters.Duct.k_T0,'omega_max',model.parameters.omega_m_max,'omega_min',model.parameters.omega_m_min);
allocator_cfg=ca_allocator_config(cfg);allocator_cfg.sample_hz=400;
delta_hat=model.trim_delta_rad;held=delta_hat;pending=held;motor=model.hover_motor_rad_s;
sensor_cfg=shc09_module_params(cfg,'sensors');sensor_cfg.sample_hz=400;
sensor_cfg.filter_h1_hz=plan.controller.indi_output_filter_hz;sensor_cfg.filter_h2_hz=plan.controller.indi_input_filter_hz;
sensor=ca_sensor_init(sensor_cfg,delta_hat);memory=[];solve=0;tick=0;info=struct('lambda',NaN,'mode',0,'beta',NaN);
fields={'position','velocity','euler','omega','estimated_position','estimated_velocity','estimated_euler','measured_omega', ...
    'omega_sp','gamma_sp','gamma_ff','measured_gamma','v_h','v_c','velocity_sp','acceleration_sp','attitude_command'};
for field=fields,L.(field{1})=zeros(n,3);end
L.actual_delta=zeros(n,6);L.estimated_delta=zeros(n,6);L.command=zeros(n,6);L.held_command=zeros(n,6);
L.lambda=NaN(n,1);L.mode=zeros(n,1);L.solve_time_s=zeros(n,1);L.estimator_updated=false(n,1);
L.estimator_bias=zeros(n,3);L.aero_outside=false(n,1);L.estimate_attitude_error_rad=zeros(n,1);
L.raw_navigation_position=zeros(n,3);L.navigation_origin_offset=navigation_origin_offset;
L.control_updated=false(n,1);L.gnss_fresh=false(n,1);L.estimated_variance=zeros(n,3);
L.pwm_time=zeros(ceil(52*333)+2,1);L.pwm_command=zeros(ceil(52*333)+2,6);count=0;
started=tic;
for k=1:n
    t=ref.time_s(k);physical=ca_plant_outputs(state,model,cfg,t);
    [packet,observation,nav]=ppid_sensor_step(state,physical,nav,cfg,true,plan);
    bus.publish('sensor_navigation',struct('packet',packet,'observation',observation),t);
    estimate=shc09_navigation_module(bus,fusion,t);
    assert(estimate.attitude_valid&&estimate.position_valid&&estimate.origin_valid&&estimate.yaw_aligned&&estimate.fault_code==0, ...
        'ppid:EstimatorInvalid','ECL估计失效，不回退真值。');
    if mod(k-1,2)==0
        [measurement,sensor]=ca_sensor_step(estimate.rate_earth_corrected,delta_hat,zeros(3,1),sensor,sensor_cfg);
        fb=struct('position',estimate.position-navigation_origin_offset,'velocity',estimate.velocity,'rotation',estimate.rotation, ...
            'omega',estimate.rate_earth_corrected);
        r=struct('position',ref.position_ned_m(k,:)','velocity',ref.velocity_ned_m_s(k,:)', ...
            'acceleration',ref.acceleration_ned_m_s2(k,:)','yaw',ref.euler_rad(k,3), ...
            'rotation_ff',ref.rotation_ff(:,:,k),'omega_ff',ref.omega_body_rad_s(k,:)','gamma_ff',ref.alpha_body_rad_s2(k,:)');
        [demand,motor,memory,signals]=ppid_control_step(fb,r,nominal,plan.controller,measurement,memory,tick);
        timing=ca_pwm_timing(t,allocator_cfg,held);timer=tic;
        [pending,info]=ca_allocate(method,demand.v_h,demand.v_c,delta_hat,model,allocator_cfg,timing);
        solve=toc(timer);L.control_updated(k)=true;tick=tick+1;
    end
    if abs(scheduler.next_pwm_time()-t)<1e-10,latch(t);end
    L.position(k,:)=state.position';L.velocity(k,:)=state.velocity';L.euler(k,:)=ca_rotation_euler(state.rotation)';L.omega(k,:)=state.omega';
    L.raw_navigation_position(k,:)=estimate.position';
    L.estimated_position(k,:)=(estimate.position-navigation_origin_offset)';L.estimated_velocity(k,:)=estimate.velocity';
    L.estimated_euler(k,:)=ca_rotation_euler(estimate.rotation)';L.measured_omega(k,:)=estimate.rate_earth_corrected';
    L.actual_delta(k,:)=state.delta';L.estimated_delta(k,:)=delta_hat';L.command(k,:)=pending';L.held_command(k,:)=held';
    L.omega_sp(k,:)=signals.omega_sp';L.gamma_sp(k,:)=signals.gamma_sp';L.gamma_ff(k,:)=signals.gamma_ff';
    L.velocity_sp(k,:)=signals.velocity_sp';L.acceleration_sp(k,:)=signals.acceleration_sp';
    L.attitude_command(k,:)=ca_rotation_euler(signals.rotation_sp)';L.measured_gamma(k,:)=measurement.alpha';
    L.v_h(k,:)=demand.v_h';L.v_c(k,:)=demand.v_c';L.lambda(k)=info.lambda;L.mode(k)=info.mode;L.solve_time_s(k)=solve;
    L.estimator_updated(k)=estimate.updated;L.estimator_bias(k,:)=estimate.gyro_bias';L.gnss_fresh(k)=observation.fresh(1);
    L.estimated_variance(k,:)=estimate.position_variance';L.aero_outside(k)=physical.table_extrapolated;
    L.estimate_attitude_error_rad(k)=acos(min(1,max(-1,(trace(state.rotation'*estimate.rotation)-1)/2)));
    if k==n,break;end
    now=t;finish=ref.time_s(k+1);
    while now<finish-1e-11
        stop=min(finish,scheduler.next_pwm_time());duration=stop-now;
        state=ca_plant_step(state,held,motor,duration,model,cfg,now);
        delta_hat=ca_actuator_step(delta_hat,held,cfg.tau_model_s,duration,deg2rad(cfg.rate_limit_deg_s));
        now=stop;
        if now<finish-1e-11,latch(now);end
    end
    assert(all(isfinite([state.position;state.velocity;state.omega]))&&norm(state.omega)<100,'ppid:Nonfinite','对象状态异常。');
    if mod(k-1,8000)==0,fprintf('PPID_PROGRESS %s t=%.1f elapsed=%.1fs\n',method,t,toc(started));end
end
L.time_s=ref.time_s;L.name=char(method);L.pwm_time=L.pwm_time(1:count);L.pwm_command=L.pwm_command(1:count,:);
L.elapsed_s=toc(started);L.update_counts=rmfield(memory,{'integral','previous_velocity','derivative','velocity_sp','acceleration_sp','rotation_sp','omega_sp','motor'});
L.truth_feedback=false;L.control_interface_fields=fieldnames(fb);L.allocator_interface_fields=fieldnames(allocator_cfg);
L.ekf_main_updates=sum(L.estimator_updated);L.ekf_rate_hz=(sum(L.estimator_updated)-1)/52;
L.sensor_profile=plan.sensors.profile;L.simulation_source="research/ppid_pindi/ppid_simulate.m";
    function latch(time)
        % 非整比PWM时钟在对象积分内部精确处理；下发最新候选而非读取真实舵角。
        held=pending;count=count+1;L.pwm_time(count)=time;L.pwm_command(count,:)=held';scheduler.advance_pwm();
    end
end
