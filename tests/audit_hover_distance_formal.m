function checks=audit_hover_distance_formal(output)
% 正式批独立审计：不重飞，核对输入、状态、需求拆分、PWM历史与优先级几何。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
addpath(fullfile(root,'research','hover_distance_formal_20261102'));
audit=fullfile(output,'audit');assert(~isfolder(audit));mkdir(audit);
lock=jsondecode(fileread(fullfile(output,'formal_lock.json')));assert(strcmp(jsonencode(lock.sources),jsonencode(hd_sources(root))));
for item=reshape(lock.formal_sources,1,[])
    fid=fopen(fullfile(root,item.path),'rb');bytes=fread(fid,Inf,'*uint8');fclose(fid);
    assert(string(item.sha256)==allocation_comparison_hash(bytes,true));
end
status=readtable(fullfile(output,'status.csv'),'TextType','string');summary=readtable(fullfile(output,'summary.csv'),'TextType','string');
assert(height(status)==15&&height(unique(status(:,{'method','seed'})))==15);
rows=table();all_metrics=table();geometry=table();comparisons=table();maximum_trim=0;maximum_metric=0;maximum_equality=0;maximum_lambda=0;
inputs=table();
for seed=[501,502,503]
    input=load(fullfile(output,'inputs',sprintf('seed%d.mat',seed)));
    regenerated=ppid_noise(input.cfg,input.ref,input.plan);regenerated.disturbance_series=input.cfg.disturbance_series;
    assert(isequaln(regenerated,input.experiment));
    assert(allocation_comparison_hash({input.cfg,input.model,input.ref,regenerated})==string(input.signature));
    inputs=[inputs;table(seed,string(input.signature),allocation_comparison_hash(input.ref), ...
        allocation_comparison_hash({input.plan.controller,input.plan.sensors,input.model,input.cfg.disturbance_series}), ...
        'VariableNames',{'seed','input_signature','reference_signature','controller_sensors_model_disturbance_signature'})]; %#ok<AGROW>
    for method=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"]
        st=status(status.seed==seed&status.method==method,:);path=fullfile(output,'logs',sprintf('%s_s%d.mat',method,seed));
        if ~isfile(path),continue;end
        d=load(path);L=d.L;
        assert(isequaln(d.cfg,input.cfg)&&isequaln(d.model,input.model)&&isequaln(d.ref,input.ref)&&isequaln(d.plan,input.plan));
        assert(string(d.signature)==string(input.signature));legacy_passed=true;
        command_excess=max(abs(L.command),[],'all')-deg2rad(40);
        try
            hd_check_log(L,d.ref,d.plan);
        catch problem
            % 旧检查把原有1e-7弧度容差写成1e-7度；只识别这一明确的单位不一致。
            assert(strcmp(problem.stack(1).name,'hd_check_log')&&problem.stack(1).line==13);
            assert(command_excess<=d.cfg.constraint_tolerance+1e-12);
            assert(max(abs(rad2deg(L.actual_delta)),[],'all')<=40+1e-7);
            % 在日志副本上仅去除已确认的容差内越界，验证该检查的其余断言；原日志不改。
            copy=L;copy.command=min(deg2rad(40),max(-deg2rad(40),copy.command));hd_check_log(copy,d.ref,d.plan);clear copy
            legacy_passed=false;
        end
        assert(all(isfinite([L.position,L.velocity,L.euler,L.omega,L.actual_delta,L.estimated_position,L.estimated_euler,L.measured_omega]),'all'));
        assert(~any(L.aero_outside)&&max(vecnorm(L.omega,2,2))<100);
        q=L.time_s>=10&L.time_s<22;qc=q&L.control_updated;ix=find(qc);
        estimated=L.estimated_position(q,1:2)-d.ref.position_ned_m(q,1:2);truth=L.position(q,1:2)-d.ref.position_ned_m(q,1:2);
        values=[sqrt(mean(sum(estimated.^2,2))),sqrt(mean(sum(truth.^2,2))), ...
            rad2deg(sqrt(mean(L.estimated_euler(q,1).^2))),rad2deg(sqrt(mean(L.euler(q,1).^2))), ...
            rad2deg(sqrt(mean((L.measured_omega(q,3)-d.ref.omega_body_rad_s(q,3)).^2))), ...
            rad2deg(sqrt(mean((L.omega(q,3)-d.ref.omega_body_rad_s(q,3)).^2)))];
        metrics=hdf_metrics(L,d.ref,d.plan,seed);
        saved=summary(summary.seed==seed&summary.method==method,:);
        if isempty(saved),saved=struct2table(metrics,'AsArray',true);end
        fields={'horizontal_rmse_m','true_horizontal_rmse_m','roll_rmse_deg','true_roll_rmse_deg','yaw_rate_rmse_deg_s','true_yaw_rate_rmse_deg_s'};
        error=max(abs(values-saved{1,fields}));maximum_metric=max(maximum_metric,error);assert(error<1e-10);
        metrics.legacy_log_check_passed=legacy_passed;metrics.command_excess_rad=command_excess;
        metrics.configured_command_tolerance_rad=d.cfg.constraint_tolerance;metrics.original_driver_status=st.status;
        if ~metrics.lambda_applicable
            metrics.high_priority_fallback_duration_s=NaN;metrics.engineering_fallback_duration_s=NaN;metrics.all_fallback_duration_s=NaN;
        end
        all_metrics=[all_metrics;struct2table(metrics,'AsArray',true)]; %#ok<AGROW>
        sc=shc09_module_params(d.cfg,'sensors');sc.sample_hz=400;sc.filter_h1_hz=d.plan.controller.indi_output_filter_hz;
        sc.filter_h2_hz=d.plan.controller.indi_input_filter_hz;sensor=ca_sensor_init(sc,d.model.trim_delta_rad);
        for sample=reshape(find(L.control_updated),1,[])
            [measurement,sensor]=ca_sensor_step(L.measured_omega(sample,:)',L.estimated_delta(sample,:)',zeros(3,1),sensor,sc);
            trim=d.model.acceleration_matrix*measurement.delta_feedback-measurement.alpha;
            maximum_trim=max(maximum_trim,max(abs(trim-L.v_h(sample,:)')));
        end
        assert(maximum_trim<1e-10);
        pwm_index=min(numel(L.time_s),2*floor(L.pwm_time*400+1e-8)+1);
        assert(max(abs(L.pwm_command-L.command(pwm_index,:)),[],'all')<1e-10);
        rows=[rows;table(method,seed,error,sum(q),sum(qc),sum(L.aero_outside), ...
            'VariableNames',{'method','seed','maximum_metric_error','state_samples','control_samples','aero_domain_failures'})]; %#ok<AGROW>
        if startsWith(method,'PCA')
            time=L.time_s(L.control_updated);held=interp1(L.pwm_time,L.pwm_command,time-1e-9,'previous',NaN);held(1,:)=d.model.trim_delta_rad';
            shim=struct('v_h',L.v_h(L.control_updated,:),'v_c',L.v_c(L.control_updated,:), ...
                'estimated_delta_rad',L.estimated_delta(L.control_updated,:),'allocation_held_command_rad',held);
            cfg=ca_allocator_config(d.cfg);cfg.sample_hz=400;G=ca_priority_polytope_audit(shim,d.model,cfg,time,[10,22-1/400]);
            normal=L.mode(ix)==0;predicted=G.static_lambda_max;high=G.static_high_feasible;
            if method=="PCA_PREDICTIVE",predicted=G.dynamic_lambda_max;high=G.dynamic_high_feasible;end
            assert(all(isfinite(predicted(normal))));
            discrepancy=max(abs(L.lambda(ix(normal))-predicted(normal)));maximum_lambda=max(maximum_lambda,discrepancy);assert(discrepancy<1e-5);
            equality=NaN(numel(ix),1);
            for j=reshape(find(normal),1,[])
                i=ix(j);effect=d.model.acceleration_matrix*L.command(i,:)';
                if method=="PCA_PREDICTIVE"
                    held_index=(i+1)/2;timing=ca_pwm_timing(L.time_s(i),cfg,held(held_index,:)');
                    at=ca_actuator_step(L.estimated_delta(i,:)',timing.held_command,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
                    f=exp(-timing.hold_s./cfg.tau_model_s);effect=d.model.acceleration_matrix*(f.*at+(1-f).*L.command(i,:)');
                end
                equality(j)=norm(effect-L.v_h(i,:)'-L.lambda(i)*L.v_c(i,:)',Inf);
            end
            residual=max(equality,[],'omitnan');maximum_equality=max(maximum_equality,residual);assert(residual<1e-5);
            G.mode=L.mode(ix);G.observed_lambda=L.lambda(ix);G.equality_residual=equality;
            writetable(G,fullfile(audit,sprintf('geometry_%s_s%d.csv',method,seed)));
            geometry=[geometry;table(method,seed,discrepancy,residual,sum(~high)/400, ...
                'VariableNames',{'method','seed','lambda_error','equality_error','trim_alone_infeasible_s'})]; %#ok<AGROW>
        end
    end
    % 成对闭环状态差异不设为相等门槛；饱和时两个算法可能选择不同的力矩方向。
    a=load(fullfile(output,'logs',sprintf('DA_NS_s%d.mat',seed)),'L');b=load(fullfile(output,'logs',sprintf('WLS_s%d.mat',seed)),'L');
    q=a.L.time_s>=10&a.L.time_s<22;
    command=pinv(input.model.acceleration_matrix)*(a.L.v_h(q,:)+a.L.v_c(q,:))';
    fraction=mean(any(command<input.model.command_lower-1e-10|command>input.model.command_upper+1e-10,1));
    comparisons=[comparisons;table(seed,max(abs(a.L.position-b.L.position),[],'all'), ...
        max(abs(a.L.euler-b.L.euler),[],'all'),max(abs(a.L.command-b.L.command),[],'all'),fraction, ...
        'VariableNames',{'seed','DA_WLS_position_max_difference_m','DA_WLS_euler_max_difference_rad','DA_WLS_command_max_difference_rad','DA_main_pinv_outside_box_fraction'})]; %#ok<AGROW>
end
old=load(fullfile(root,'results','hover_distance_precheck_20261102_a1_L085_Y280_pred','logs','PCA_PREDICTIVE_s501.mat'),'L');
new=load(fullfile(output,'logs','PCA_PREDICTIVE_s501.mat'),'L');
repeat=max(abs([old.L.position-new.L.position,old.L.euler-new.L.euler,old.L.omega-new.L.omega,old.L.actual_delta-new.L.actual_delta]),[],'all');
assert(repeat<1e-10,'501同输入回归未一致。');
writetable(rows,fullfile(audit,'independent_metric_checks.csv'));writetable(geometry,fullfile(audit,'geometry_summary.csv'));
writetable(comparisons,fullfile(audit,'DA_NS_WLS_comparison.csv'));
assert(numel(unique(inputs.reference_signature))==1&&numel(unique(inputs.controller_sensors_model_disturbance_signature))==1);
writetable(inputs,fullfile(audit,'independent_input_checks.csv'));
checks=struct('logs_verified',height(rows),'expected_logs',15,'all_completed',all(status.status=="completed"), ...
    'maximum_metric_error',maximum_metric,'maximum_trim_error',maximum_trim,'maximum_geometry_lambda_error',maximum_lambda, ...
    'maximum_equality_error',maximum_equality,'seed501_precheck_max_state_difference',repeat, ...
    'same_input_per_seed_verified',true,'source_sha_verified',true,'simulations_rerun',0);
checks.original_driver_completed=sum(status.status=="completed");checks.original_driver_failed=sum(status.status=="failed");
checks.full_40s_logs=height(all_metrics);checks.valid_under_original_configured_tolerance=all(all_metrics.valid_data&all_metrics.no_divergence);
checks.all_15_flights_completed=height(all_metrics)==15&&all(all_metrics.completed_40s);
checks.legacy_command_tolerance_unit_mismatches=sum(~all_metrics.legacy_log_check_passed);
writetable(all_metrics,fullfile(audit,'audited_per_run_metrics.csv'));
fid=fopen(fullfile(audit,'independent_checks.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));fclose(fid);disp(checks);
end
