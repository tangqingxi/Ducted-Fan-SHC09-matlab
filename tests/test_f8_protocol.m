function report=test_f8_protocol()
% 在任何正式F8仿真前检查解析导数、前馈实际消费、约束及独立门禁语义。
ca_setup();frozen=ca_f8_protocol();maximum_rotation_derivative_error=0;maximum_alpha_error=0;
for id=["F8-R","F8-D"]
    [c,m,r,p]=ca_f8_protocol(id,101);dt=1/c.sample_hz;n=numel(r.time_s);
    assert(~isfield(ca_config(),'f8_feedforward_enabled'),'旧配置不得自动开启新前馈。');
    assert(p.seed==101&&isequal(p.seeds(:),[101;102;103]));
    assert(max(abs(r.position_ned_m(1,:)-r.position_ned_m(end,:)))<1e-10);
    for field=["velocity_ned_m_s","acceleration_ned_m_s2","jerk_ned_m_s3","snap_ned_m_s4"]
        assert(max(abs(r.(field)([1,end],:)),[],'all')<1e-10);
    end
    fields=["position_ned_m","velocity_ned_m_s","acceleration_ned_m_s2","jerk_ned_m_s3","snap_ned_m_s4"];
    for k=1:4
        numerical=(r.(fields(k))(3:end,:)-r.(fields(k))(1:end-2,:))/(2*dt);
        assert(max(abs(numerical-r.(fields(k+1))(2:end-1,:)),[],'all')<1e-3);
    end
    for k=2:80:n-1
        derivative=(r.rotation_ff(:,:,k+1)-r.rotation_ff(:,:,k-1))/(2*dt);
        error=norm(derivative-r.rotation_ff(:,:,k)*ca_skew(r.omega_body_rad_s(k,:)'),'fro');
        maximum_rotation_derivative_error=max(maximum_rotation_derivative_error,error);assert(error<1e-4);
        alpha=(r.omega_body_rad_s(k+1,:)-r.omega_body_rad_s(k-1,:))/(2*dt);
        maximum_alpha_error=max(maximum_alpha_error,max(abs(alpha-r.alpha_body_rad_s2(k,:))));
        assert(max(abs(alpha-r.alpha_body_rad_s2(k,:)))<1e-3);
    end
    index=find(vecnorm(r.velocity_ned_m_s,2,2)>0.5,1,'first');
    reference=struct('position',r.position_ned_m(index,:)','velocity',r.velocity_ned_m_s(index,:)', ...
        'acceleration',r.acceleration_ned_m_s2(index,:)','yaw',r.euler_rad(index,3), ...
        'rotation_ff',r.rotation_ff(:,:,index),'omega_ff',r.omega_body_rad_s(index,:)','alpha_ff',r.alpha_body_rad_s2(index,:)');
    [R,motor,w,a]=ca_f8_position_control(reference.position,reference.velocity,reference,m,c);
    assert(norm(R-reference.rotation_ff,'fro')<1e-10&&norm(w-reference.omega_ff)<1e-10&&norm(a-reference.alpha_ff)<1e-10);
    thrust=m.mass_kg*norm(reference.acceleration-[0;0;m.parameters.g]);assert(abs(motor-sqrt(thrust/m.parameters.Duct.k_T0))<1e-9);
    [oldR,~]=ca_position_control(reference.position,reference.velocity,reference.yaw,m,c,reference.position);
    assert(norm(oldR-R,'fro')>1e-3,'移动时零误差不应仍使用旧速度阻尼来抵消计划速度。');
    [limited,motor]=ca_f8_position_control(reference.position+[100;100;100],100*ones(3,1),reference,m,c);
    assert(rad2deg(acos(limited(3,3)))<=45+1e-9&&(motor/m.parameters.omega_m_max)^2<=0.9+1e-10);
    L=struct('name',"PCA_STATIC",'position_ned_m',r.position_ned_m,'velocity_ned_m_s',r.velocity_ned_m_s, ...
        'euler_rad',r.euler_rad,'omega_rad_s',r.omega_body_rad_s,'rotation_error_rad',zeros(n,1), ...
        'estimated_attitude_error_rad',zeros(n,1),'command_rad',zeros(n,6),'actual_delta_rad',zeros(n,6), ...
        'motor_command_rad_s',m.hover_motor_rad_s*ones(n,1),'table_extrapolated',false(n,1),'mode',zeros(n,1),'lambda',ones(n,1));
    L.rotation_error_rad(round(20/dt)+1)=deg2rad(7);[~,checks]=f8_evaluate_run(L,c,m,r,p);
    assert(checks.run_task_passed&&~checks.priority_duration_excited&&~checks.priority_mechanism_claim_allowed);
    L.command_rad(:)=deg2rad(40);[~,checks]=f8_evaluate_run(L,c,m,r,p);
    assert(checks.run_task_passed,'触及硬限幅的占比不再套用悬停10%淘汰规则。');
    L.position_ned_m(:,1)=L.position_ned_m(:,1)+2;[~,checks]=f8_evaluate_run(L,c,m,r,p);
    assert(checks.valid_data&&~checks.tracking_requirements_passed&&~checks.run_task_passed);
    L.table_extrapolated(1)=true;[~,checks]=f8_evaluate_run(L,c,m,r,p);assert(~checks.valid_data);
end
report=struct('protocol_id',string(frozen.protocol_id),'scenarios_checked',2,'analytic_rotation_derivative_error',maximum_rotation_derivative_error, ...
    'analytic_alpha_error',maximum_alpha_error,'feedforward_consumed',true,'hover_gate_not_reused',true,'formal_simulations_run',0);
disp(report);
end
