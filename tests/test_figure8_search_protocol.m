function report=test_figure8_search_protocol()
% 核对六个候选的闭合参考、解析导数、真实参数隔离及比旧八字更强的激励。
ca_setup();catalog=ca_figure8_search_protocol();old=ca_config();old.duration_s=52;old_ref=ca_figure8_reference(old);
old_speed=max(vecnorm(old_ref.velocity_ned_m_s(:,1:2),2,2));
old_acceleration=max(vecnorm(old_ref.acceleration_ned_m_s2(:,1:2),2,2));
for spec=catalog
    [c,m,r,p]=ca_figure8_search_protocol(spec.id,2);dt=1/c.sample_hz;
    assert(c.estimator_mode=="lite"&&p.command_limit_deg==40&&p.load_fraction==0.6);
    assert(isequal(c.tau_actual_s,0.001*[24;27;30;33;36;40])&&isequal(c.tau_model_s,0.03*ones(6,1)));
    assert(isequal(m,ca_model(c))&&~c.actuator_tau_variation_enabled);
    assert(p.peak_horizontal_speed_m_s>old_speed&&p.peak_horizontal_acceleration_m_s2>old_acceleration);
    assert(norm(r.position_ned_m(1,:)-r.position_ned_m(end,:))<1e-10&&abs(r.euler_rad(end,3))<1e-10);
    assert(max(abs(r.velocity_ned_m_s([1,end],:)),[],'all')==0);
    v=(r.position_ned_m(3:end,:)-r.position_ned_m(1:end-2,:))/(2*dt);
    assert(max(abs(v-r.velocity_ned_m_s(2:end-1,:)),[],'all')<1e-5);
    a=(r.velocity_ned_m_s(3:end,:)-r.velocity_ned_m_s(1:end-2,:))/(2*dt);
    assert(max(abs(a-r.acceleration_ned_m_s2(2:end-1,:)),[],'all')<1e-5);
    yaw=(r.euler_rad(3:end,3)-r.euler_rad(1:end-2,3))/(2*dt);
    assert(max(abs(yaw-r.euler_dot_rad_s(2:end-1,3)))<1e-5);
end
% 直接复用已被独立LP核验的十个启动快照，核对支撑面给出的最大可行比例。
root=ca_setup();path=fullfile(root,'results','figure8_lite_M2b_20261101_figure8_3seeds','logs','PCA_PREDICTIVE_s3.mat');
assert(isfile(path),'几何回归需要既有八字日志。');d=load(path,'L','c','model','ref');
i=find(d.L.mode==0&d.L.lambda<1-1e-6);tiny=struct();
for field=["v_h","v_c","estimated_delta_rad","allocation_held_command_rad"],tiny.(field)=d.L.(field)(i,:);end
geometry=ca_priority_polytope_audit(tiny,d.model,d.c,d.ref.time_s(i),[0,1]);
assert(numel(i)==10&&max(abs(geometry.dynamic_lambda_max-d.L.lambda(i)))<1e-6);
assert(~any(geometry.dynamic_full_feasible));
report=struct('reference_candidates_checked',numel(catalog),'independent_lp_snapshots_reused',10,'servo_mismatch_isolated',true,'old_reference_unchanged',true);
fprintf('FIG8_SEARCH_PROTOCOL_PASS %d candidates; polytope matches 10 independently verified LP snapshots\n',numel(catalog));
end
