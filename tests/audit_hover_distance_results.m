function checks=audit_hover_distance_results(folders,output)
% 对新场景日志做独立后处理，结果写全新审计目录，禁止重跑仿真或改原批数据。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
folders=string(folders);assert(~isfolder(output));mkdir(output);
sources=hd_sources(root);rows=table();geometry=table();maximum_increment=0;maximum_metric=0;maximum_equality=0;maximum_lambda=0;
signatures=strings(0,1);settings=strings(0,1);lambda_stats=table();gate_rejected=false;any_failed_precheck=false;all_precheck=true;
for folder=reshape(folders,1,[])
    previous=jsondecode(fileread(fullfile(folder,'sources.json')));assert(strcmp(jsonencode(previous),jsonencode(sources)));
    request=jsondecode(fileread(fullfile(folder,'request.json')));all_precheck=all_precheck&&string(request.stage)=="precheck";
    status=readtable(fullfile(folder,'status.csv'),'TextType','string');S=readtable(fullfile(folder,'summary.csv'),'TextType','string');
    for row=reshape(find(status.status=="completed"),1,[])
        d=load(fullfile(folder,'logs',sprintf('%s_s%d.mat',status.method(row),status.seed(row))));L=d.L;
        hd_check_log(L,d.ref,d.plan);q=L.time_s>=10&L.time_s<22;control=L.control_updated;qc=q&control;
        position=L.estimated_position(q,1:2)-d.ref.position_ned_m(q,1:2);
        horizontal=sqrt(mean(sum(position.^2,2)));roll=rad2deg(sqrt(mean(L.estimated_euler(q,1).^2)));
        yaw=rad2deg(sqrt(mean((L.measured_omega(q,3)-d.ref.omega_body_rad_s(q,3)).^2)));
        old=S(S.method==status.method(row)&S.seed==status.seed(row),:);
        any_failed_precheck=any_failed_precheck||~old.precheck_passed;
        error=max(abs([horizontal-old.horizontal_rmse_m,roll-old.roll_rmse_deg,yaw-old.yaw_rate_rmse_deg_s]));
        maximum_metric=max(maximum_metric,error);assert(error<1e-10);
        experiment=ppid_noise(d.cfg,d.ref,d.plan);experiment.disturbance_series=d.cfg.disturbance_series;
        assert(allocation_comparison_hash({d.cfg,d.model,d.ref,experiment})==string(d.signature));
        signatures(end+1,1)=string(d.signature);settings(end+1,1)=sprintf('L%.2f_Y%.0f_s%d',d.spec.roll_load_fraction,d.spec.yaw_rate_peak_deg_s,d.spec.seed); %#ok<AGROW>
        % 独立重建H1/H2的历史输入，确认高优先级只含配平补偿。
        sc=shc09_module_params(d.cfg,'sensors');sc.sample_hz=400;
        sc.filter_h1_hz=d.plan.controller.indi_output_filter_hz;sc.filter_h2_hz=d.plan.controller.indi_input_filter_hz;
        sensor=ca_sensor_init(sc,d.model.trim_delta_rad);
        for sample=reshape(find(control),1,[])
            [measurement,sensor]=ca_sensor_step(L.measured_omega(sample,:)',L.estimated_delta(sample,:)',zeros(3,1),sensor,sc);
            expected=d.model.acceleration_matrix*measurement.delta_feedback-measurement.alpha;
            maximum_increment=max(maximum_increment,max(abs(expected-L.v_h(sample,:)')));
        end
        assert(maximum_increment<1e-10);
        origin_error=max(abs(L.raw_navigation_position-L.estimated_position-L.navigation_origin_offset'),[],'all');assert(origin_error<1e-10);
        index=min(numel(L.time_s),2*floor(L.pwm_time*400+1e-8)+1);
        assert(max(abs(L.pwm_command-L.command(index,:)),[],'all')<1e-10,'PWM下发没有对应最新控制指令。');
        rows=[rows;table(string(L.name),d.spec.seed,horizontal,roll,yaw,error,origin_error, ...
            'VariableNames',{'method','seed','horizontal_rmse_m','roll_rmse_deg','yaw_rate_rmse_deg_s','metric_error','origin_identity_error'})]; %#ok<AGROW>
        if startsWith(string(L.name),'PCA')
            time=L.time_s(control);held=interp1(L.pwm_time,L.pwm_command,time-1e-9,'previous',NaN);held(1,:)=d.model.trim_delta_rad';
            shim=struct('v_h',L.v_h(control,:),'v_c',L.v_c(control,:),'estimated_delta_rad',L.estimated_delta(control,:), ...
                'allocation_held_command_rad',held);cfg=ca_allocator_config(d.cfg);cfg.sample_hz=400;
            G=ca_priority_polytope_audit(shim,d.model,cfg,time,[10,22-1/400]);assert(height(G)==4800);
            k=find(qc);normal=L.mode(k)==0;values=L.lambda(k);predictive=string(L.name)=="PCA_PREDICTIVE";
            predicted=G.static_lambda_max;high_feasible=G.static_high_feasible;
            if predictive,predicted=G.dynamic_lambda_max;high_feasible=G.dynamic_high_feasible;end
            discrepancy=max(abs(values(normal)-predicted(normal)));maximum_lambda=max(maximum_lambda,discrepancy);assert(discrepancy<1e-5);
            equality=NaN(numel(k),1);
            for j=reshape(find(normal),1,[])
                i=k(j);effect=d.model.acceleration_matrix*L.command(i,:)';
                if predictive
                    timing=ca_pwm_timing(L.time_s(i),cfg,shim.allocation_held_command_rad(time==L.time_s(i),:)');
                    at=ca_actuator_step(L.estimated_delta(i,:)',timing.held_command,cfg.tau_model_s,timing.delay_s,deg2rad(cfg.rate_limit_deg_s));
                    f=exp(-timing.hold_s./cfg.tau_model_s);effect=d.model.acceleration_matrix*(f.*at+(1-f).*L.command(i,:)');
                end
                equality(j)=norm(effect-L.v_h(i,:)'-L.lambda(i)*L.v_c(i,:)',Inf);
            end
            maximum_equality=max(maximum_equality,max(equality,[],'omitnan'));assert(maximum_equality<1e-5);
            G.mode=L.mode(k);G.observed_lambda=values;G.equality_residual=equality;
            writetable(G,fullfile(output,sprintf('geometry_%s_s%d_L%.2f.csv',L.name,d.spec.seed,d.spec.roll_load_fraction)));
            geometry=[geometry;table(string(L.name),d.spec.seed,sum(normal),sum(~high_feasible)/400,discrepancy,max(equality,[],'omitnan'), ...
                'VariableNames',{'method','seed','normal_samples','high_target_alone_infeasible_s','lambda_error','equality_error'})]; %#ok<AGROW>
            sorted=sort(values(normal));active=values(normal&values<1-1e-6);active=sort(active);[minimum,where]=min(values,[],'omitnan');
            lambda_stats=[lambda_stats;table(string(L.name),d.spec.seed,minimum,L.time_s(k(where)), ...
                percentile(sorted,.01),percentile(sorted,.05),percentile(active,.01),percentile(active,.05), ...
                sum(values(normal)<.3)/400,sum(values(normal)<.6)/400, ...
                'VariableNames',{'method','seed','minimum_lambda','minimum_time_s','normal_p01','normal_p05','scaled_p01','scaled_p05','below_030_s','below_060_s'})]; %#ok<AGROW>
        end
    end
end
for setting=unique(settings)'
    assert(numel(unique(signatures(settings==setting)))==1,'相同工况种子输入哈希不一致。');
end
% 本轮不合格预检必须被正式冻结入口拒绝；不修改任何锁或测试门槛。
if numel(folders)==2&&all_precheck&&any_failed_precheck
    assert(~isfile(fullfile(root,'research','hover_distance','formal_lock.json')));
    try
        hd_freeze(folders(1),folders(2));
    catch problem
        assert(contains(problem.message,'预检未达要求'));gate_rejected=true;
    end
    assert(gate_rejected&&~isfile(fullfile(root,'research','hover_distance','formal_lock.json')));
end

writetable(rows,fullfile(output,'independent_metric_checks.csv'));writetable(geometry,fullfile(output,'geometry_summary.csv'));
writetable(lambda_stats,fullfile(output,'lambda_diagnostics.csv'));
checks=struct('logs_verified',height(rows),'maximum_metric_error',maximum_metric,'maximum_increment_error',maximum_increment, ...
    'maximum_geometry_lambda_error',maximum_lambda,'maximum_equality_error',maximum_equality, ...
    'same_inputs_verified',true,'sources_unchanged',true,'formal_gate_rejected_failed_prechecks',gate_rejected,'simulations_rerun',0);
fid=fopen(fullfile(output,'independent_checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));disp(checks);disp(lambda_stats);
end

function value=percentile(sorted,fraction)
% 无缩放样本时保留缺失，不把缺失误写成λ=1或0。
value=NaN;if ~isempty(sorted),value=sorted(max(1,ceil(fraction*numel(sorted))));end
end
