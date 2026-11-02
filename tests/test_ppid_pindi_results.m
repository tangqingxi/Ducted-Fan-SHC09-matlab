function checks=test_ppid_pindi_results(folder)
% 只加载新研究日志，独立核对控制公式、多速率计数与完整指标，不重跑仿真。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));
status=readtable(fullfile(folder,'status.csv'),'TextType','string');summary=readtable(fullfile(folder,'summary.csv'),'TextType','string');
assert(all(status.status=="completed")&&height(status)==height(summary));
max_formula=0;max_metric=0;signatures=strings(height(status),1);
max_increment=0;max_frame=0;
timing=table();diagnostic_folder=fullfile(folder,'diagnostics_100hz');
if ~isfolder(diagnostic_folder),mkdir(diagnostic_folder);end
for i=1:height(status)
    d=load(fullfile(folder,'logs',sprintf('%s_s%d.mat',status.method(i),status.seed(i))));L=d.L;ref=d.ref;
    assert(numel(L.time_s)==41601&&L.time_s(end)==52&&~L.truth_feedback);
    assert(isequal(find(L.control_updated),(1:2:41601)'));
    assert(L.update_counts.position_updates==1301&&L.update_counts.velocity_updates==2601 ...
        &&L.update_counts.attitude_updates==5201&&L.update_counts.rate_updates==20801);
    assert(numel(L.pwm_time)==17317&&max(abs(L.pwm_time-(0:17316)'/333))<1e-10);
    assert(sum(L.estimator_updated)==5201&&sum(L.gnss_fresh)==260);
    assert(~any(ismember(string(L.control_interface_fields),["state","truth","actual_delta","tau_actual_s"])));
    assert(max(abs(rad2deg(L.command)),[],'all')<=40+1e-7&&max(abs(rad2deg(L.actual_delta)),[],'all')<=40+1e-7);
    assert(max(abs(rad2deg(diff(L.actual_delta))*800),[],'all')<=600+1e-6);
    assert(any(abs(L.actual_delta-L.estimated_delta)>1e-6,'all'),'真实舵角不应替代有时间常数失配的模型估计。');
    k=L.control_updated;gain=d.plan.controller.rate_gain(:)';
    discrepancy=max(abs(L.v_c(k,:)-L.gamma_ff(k,:)-(L.omega_sp(k,:)-L.measured_omega(k,:)).*gain),[],'all');
    max_formula=max(max_formula,discrepancy);assert(discrepancy<1e-10);
    assert(max(abs(L.gamma_sp(k,:)-L.v_c(k,:)),[],'all')<1e-10);
    assert(any(abs(L.estimated_position-L.position)>1e-6,'all'),'估计反馈不应被真值替代。');
    if isfield(L,'raw_navigation_position')
        residual=L.raw_navigation_position-L.estimated_position-L.navigation_origin_offset';
        max_frame=max(max_frame,max(abs(residual),[],'all'));assert(max_frame<1e-10);
    end
    % 从已保存的测量角速度和名义舵角重放滤波器，不积分对象，也不重跑飞行。
    sc=shc09_module_params(d.cfg,'sensors');sc.sample_hz=400;
    sc.filter_h1_hz=d.plan.controller.indi_output_filter_hz;sc.filter_h2_hz=d.plan.controller.indi_input_filter_hz;
    sensor=ca_sensor_init(sc,d.model.trim_delta_rad);
    for sample=reshape(find(k),1,[])
        [measurement,sensor]=ca_sensor_step(L.measured_omega(sample,:)',L.estimated_delta(sample,:)',zeros(3,1),sensor,sc);
        expected=d.model.acceleration_matrix*measurement.delta_feedback-measurement.alpha;
        max_increment=max(max_increment,max(abs(expected-L.v_h(sample,:)')));
    end
    assert(max_increment<1e-10,'INDI历史补偿不等于名义舵效减测量角加速度。');
    q=L.time_s>=6&L.time_s<=50;
    horizontal=sqrt(mean(sum((L.position(q,1:2)-ref.position_ned_m(q,1:2)).^2,2)));
    yaw=atan2(sin(L.euler(q,3)-ref.euler_rad(q,3)),cos(L.euler(q,3)-ref.euler_rad(q,3)));
    yaw_rms=rad2deg(sqrt(mean(yaw.^2)));
    row=summary(summary.method==status.method(i)&summary.seed==status.seed(i),:);assert(height(row)==1);
    discrepancy=max(abs([horizontal-row.horizontal_rmse_m,yaw_rms-row.yaw_rmse_deg]));
    max_metric=max(max_metric,discrepancy);assert(discrepancy<1e-9);
    T=readtable(fullfile(folder,'tracks',sprintf('%s_s%d.csv',status.method(i),status.seed(i))));
    keep=1:8:41601;assert(height(T)==5201&&max(abs(T.actual_x-L.position(keep,1)))<1e-10);
    % 求解耗时来自离线主机，不冒充400Hz硬件实时期限保证。
    elapsed=sort(L.solve_time_s(k));nsolve=numel(elapsed);
    timing=[timing;table(status.method(i),status.seed(i),mean(elapsed),elapsed(ceil(.95*nsolve)), ...
        elapsed(ceil(.99*nsolve)),max(elapsed),mean(elapsed>1/400), ...
        'VariableNames',{'method','seed','mean_s','p95_s','p99_s','max_s','fraction_over_2p5ms'})]; %#ok<AGROW>
    D=table(L.time_s(keep),'VariableNames',{'time_s'});
    for channel=1:6
        D.("actual_servo_"+channel)=rad2deg(L.actual_delta(keep,channel));
        D.("estimated_servo_"+channel)=rad2deg(L.estimated_delta(keep,channel));
        D.("held_servo_"+channel)=rad2deg(L.held_command(keep,channel));
    end
    for axis=1:3
        D.("measured_gamma_"+axis)=L.measured_gamma(keep,axis);
        D.("gamma_sp_"+axis)=L.gamma_sp(keep,axis);
        D.("estimated_bias_"+axis)=rad2deg(L.estimator_bias(keep,axis));
        D.("raw_position_"+axis)=L.raw_navigation_position(keep,axis);
        D.("relative_position_"+axis)=L.estimated_position(keep,axis);
    end
    writetable(D,fullfile(diagnostic_folder,sprintf('%s_s%d.csv',status.method(i),status.seed(i))));
    signatures(i)=d.signature;
end
for seed=unique(status.seed)'
    assert(numel(unique(signatures(status.seed==seed)))==1,'同种子跨方法输入不一致。');
end
checks=struct('logs_verified',height(status),'maximum_control_formula_error',max_formula, ...
    'maximum_metric_error',max_metric,'multirate_counts_verified',true,'pwm_clock_verified',true, ...
    'maximum_increment_reconstruction_error',max_increment,'maximum_local_frame_identity_error',max_frame, ...
    'truth_isolation_interface_verified',true,'common_inputs_verified',true,'simulations_rerun',0);
checks.numerical_sources_verified=false;
if isfile(fullfile(root,'research','ppid_pindi','formal_lock.json'))&&contains(string(folder),'formal')
    recorded=jsondecode(fileread(fullfile(folder,'sources.json')));
    current=ppid_source_manifest(root);lock=jsondecode(fileread(fullfile(root,'research','ppid_pindi','formal_lock.json')));
    assert(strcmp(jsonencode(recorded),jsonencode(current))&&strcmp(jsonencode(lock.sources),jsonencode(current)));
    checks.numerical_sources_verified=true;
end
checks.runtime=struct('matlab',version,'architecture',computer,'optimization_toolbox',ver('optim'));
writetable(timing,fullfile(folder,'solver_timing.csv'));
fid=fopen(fullfile(folder,'independent_checks.json'),'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));disp(checks);
end
