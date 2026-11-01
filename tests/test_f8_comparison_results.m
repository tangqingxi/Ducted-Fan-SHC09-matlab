function report=test_f8_comparison_results(folder)
% 从完整日志独立核对正式F8的共同输入、十二状态、门禁与优先级记录，不重跑仿真。
root=ca_setup();frozen_text=fileread(fullfile(folder,'..','frozen_protocol.json'));frozen=jsondecode(frozen_text);
pressure=ismember(string(frozen.protocol_id),["F8-P-v1.0","F8-P-v2.0"]);
if pressure
    pressure_plan=frozen;base_text=fileread(fullfile(folder,'..','base_protocol.json'));frozen=jsondecode(base_text);
    pressure_version=1;if strcmp(pressure_plan.protocol_id,'F8-P-v2.0'),pressure_version=2;end
    frozen.protocol_id=pressure_plan.protocol_id;frozen.seeds=pressure_plan.confirmation_seeds;frozen.methods=pressure_plan.confirmation_methods;
    hash=allocation_comparison_hash({base_text,frozen_text});
    assert(hash==allocation_comparison_hash({fileread(fullfile(root,'configs','f8_protocol_v1.json')),fileread(fullfile(root,'configs',sprintf('f8_pressure_protocol_v%d.json',pressure_version)))}));
else
    assert(strcmp(frozen.protocol_id,'F8-v1.0'));hash=allocation_comparison_hash(frozen_text);
    assert(hash==allocation_comparison_hash(fileread(fullfile(root,'configs','f8_protocol_v1.json'))));
end
P=readtable(fullfile(folder,'status.csv'),'TextType','string');S=readtable(fullfile(folder,'task_metrics.csv'),'TextType','string');
M=readtable(fullfile(folder,'state_metrics.csv'),'TextType','string');V=readtable(fullfile(folder,'provenance.csv'),'TextType','string');
assert(height(P)==15&&all(P.status=="completed")&&height(S)==15&&height(M)==720&&height(V)==15);
assert(all(V.truth_topics_absent)&&~any(V.smoke_test),'正式结果不得混入烟雾或未通过运行时真值审计的记录。');
engine=allocation_comparison_engine(root);
assert(all(V.engine_fingerprint==engine)&&all(V.frozen_protocol_hash==hash));
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];
maximum_csv_error=0;maximum_metric_error=0;checks_all=table();activation=table();events=table();trace=table();
verified_files=struct('path',{},'sha256',{});
scenario=unique(P.scenario_id);assert(isscalar(scenario));
for seed=reshape(frozen.seeds,1,[])
    if pressure,[expected_cfg,expected_model,expected_ref]=ca_f8_pressure_protocol(scenario,seed,pressure_version);
    else,[expected_cfg,expected_model,expected_ref]=ca_f8_protocol(scenario,seed);end
    expected_experiment=ca_prepare_experiment(expected_cfg,expected_ref.time_s);
    expected_signature=allocation_comparison_hash({expected_cfg,expected_ref,expected_experiment});clear expected_experiment;
    for method=reshape(string(frozen.methods),1,[])
        d=load(fullfile(folder,'logs',sprintf('%s_s%d.mat',method,seed)));L=d.L;c=d.c;m=d.m;r=d.ref;t=r.time_s;
        assert(d.signature==expected_signature&&isequaln(c,expected_cfg)&&isequaln(m,expected_model)&&isequaln(r,expected_ref));
        assert(~d.protocol.smoke_test&&d.protocol.seed==seed&&numel(t)==41601&&t(end)==52);
        assert(~isfield(d.protocol,'development_screen')||~d.protocol.development_screen,'不能把开发筛选混入正式确认。');
        assert(isequal(c.tau_actual_s,0.001*[24;27;30;33;36;40])&&isequal(c.tau_model_s,0.03*ones(6,1)));
        assert(c.f8_feedforward_enabled&&c.lite_velocity_aiding_enabled&&string(L.name)==method);
        assert(~isfield(ca_allocator_config(c),'tau_actual_s'));
        row=S(S.method==method&S.seed==seed,:);assert(height(row)==1);
        target=[r.position_ned_m,r.velocity_ned_m_s,rad2deg(r.euler_rad),rad2deg(r.omega_body_rad_s)];
        actual=[L.position_ned_m,L.velocity_ned_m_s,rad2deg(L.euler_rad),rad2deg(L.omega_rad_s)];
        estimate=[L.estimated_position_ned_m,L.estimated_velocity_ned_m_s,rad2deg(L.measured_euler_rad),rad2deg(L.measured_omega_rad_s)];
        error=actual-target;error(:,7:9)=rad2deg(atan2(sin(deg2rad(error(:,7:9))),cos(deg2rad(error(:,7:9)))));
        T=readtable(fullfile(folder,'tracks',sprintf('%s_s%d.csv',method,seed)));keep=1:8:numel(t);
        assert(height(T)==5201&&max(abs(T.time_s-t(keep)))<1e-12);
        for k=1:12
            for item=["target","actual","estimate"]
                values=target;if item=="actual",values=actual;elseif item=="estimate",values=estimate;end
                discrepancy=max(abs(T.(item+"_"+names(k))-values(keep,k)));
                maximum_csv_error=max(maximum_csv_error,discrepancy);assert(discrepancy<1e-10);
            end
        end
        bounds=[0,52;6,50;10,46;0,6];windows=["whole","task","cruise","initial_hover"];
        for wi=1:4
            q=t>=bounds(wi,1)&t<=bounds(wi,2);
            for k=1:12
                a=M(M.method==method&M.seed==seed&M.window==windows(wi)&M.state==names(k),:);assert(height(a)==1);
                discrepancy=max(abs([sqrt(mean(error(q,k).^2))-a.rmse,max(abs(error(q,k)))-a.peak_abs]));
                maximum_metric_error=max(maximum_metric_error,discrepancy);assert(discrepancy<1e-10);
            end
        end
        q=t>=6&t<=50;horizontal=sqrt(sum(error(q,1:2).^2,2));height_error=error(q,3);
        independent=struct('horizontal_position_rmse_m',sqrt(mean(horizontal.^2)),'horizontal_position_peak_m',max(horizontal), ...
            'altitude_rmse_m',sqrt(mean(height_error.^2)),'altitude_peak_m',max(abs(height_error)), ...
            'velocity_rmse_m_s',sqrt(mean(sum(error(q,4:6).^2,2))),'yaw_rmse_deg',sqrt(mean(error(q,9).^2)), ...
            'yaw_peak_deg',max(abs(error(q,9))),'inner_attitude_rmse_deg',sqrt(mean(rad2deg(L.rotation_error_rad(q)).^2)), ...
            'inner_attitude_peak_deg',max(rad2deg(L.rotation_error_rad(q))), ...
            'estimator_attitude_rmse_deg',sqrt(mean(rad2deg(L.estimated_attitude_error_rad(q)).^2)), ...
            'max_actual_tilt_deg',max(acosd(min(1,max(-1,cos(L.euler_rad(:,1)).*cos(L.euler_rad(:,2)))))), ...
            'max_command_deg',max(abs(rad2deg(L.command_rad)),[],'all'), ...
            'max_actual_servo_deg',max(abs(rad2deg(L.actual_delta_rad)),[],'all'), ...
            'max_actual_servo_rate_deg_s',max(abs(rad2deg(diff(L.actual_delta_rad)*c.sample_hz)),[],'all'), ...
            'max_motor_command_static_thrust_fraction',max((L.motor_command_rad_s/m.parameters.omega_m_max).^2), ...
            'command_limit_occupancy_percent',100*mean(any(abs(rad2deg(L.command_rad(q,:)))>=40-1e-5,2)), ...
            'aero_extrapolation_count',sum(L.table_extrapolated));
        if ismember('actual_servo_rate_rmse_deg_s',row.Properties.VariableNames)
            changes=diff(rad2deg(L.actual_delta_rad(q,:)));
            independent.actual_servo_rate_rmse_deg_s=sqrt(mean((changes*c.sample_hz).^2,'all'));
            independent.actual_servo_total_variation_deg=sum(abs(changes),'all');
        end
        for field=reshape(string(fieldnames(independent)),1,[])
            discrepancy=abs(independent.(field)-row.(field));maximum_metric_error=max(maximum_metric_error,discrepancy);assert(discrepancy<1e-9);
        end
        valid=all(isfinite(actual),'all')&&~any(L.table_extrapolated);envelope=true;tracking=true;
        for field=reshape(string(fieldnames(frozen.envelope)),1,[])
            if field~="role",envelope=envelope&&independent.(field)<=frozen.envelope.(field)+1e-7;end
        end
        for field=reshape(string(fieldnames(frozen.tracking_requirements)),1,[])
            if field~="role",tracking=tracking&&independent.(field)<=frozen.tracking_requirements.(field);end
        end
        assert(valid==row.valid_data&&envelope==row.flight_envelope_passed&&tracking==row.tracking_requirements_passed);
        assert((valid&&envelope&&tracking)==row.run_task_passed);
        checks_all=[checks_all;table(method,seed,valid,envelope,tracking,valid&&envelope&&tracking, ...
            'VariableNames',{'method','seed','valid_data','flight_envelope_passed','tracking_requirements_passed','run_task_passed'})];
        if startsWith(method,"PCA")
            geometry=readtable(fullfile(folder,sprintf('priority_geometry_%s_s%d.csv',method,seed)));
            assert(height(geometry)==sum(q)&&max(abs(geometry.time_s-t(q)))<1e-12);
            predicted=geometry.static_lambda_max;if method=="PCA_PREDICTIVE",predicted=geometry.dynamic_lambda_max;end
            normal=L.mode(q)==0;observed=L.lambda(q);
            assert(all(isfinite(predicted(normal)))&&max(abs(predicted(normal)-observed(normal)))<1e-6);
            for wi=1:4
                mask=t>=bounds(wi,1)&t<=bounds(wi,2);u=L.lambda(mask);scaled=L.mode(mask)==0&isfinite(u)&u<1-1e-6;
                edges=diff([false;scaled;false]);lengths=find(edges==-1)-find(edges==1);
                pwm=L.pwm_update_time_s>=bounds(wi,1)&L.pwm_update_time_s<=bounds(wi,2);
                activation=[activation;table(method,seed,windows(wi),sum(mask),sum(scaled),sum(scaled)/c.sample_hz, ...
                    max([0;lengths])/c.sample_hz,min(u,[],'omitnan'),sum(L.mode(mask)==1),sum(L.mode(mask)==2), ...
                    sum(pwm),sum(L.pwm_mode(pwm)==0&isfinite(L.pwm_lambda(pwm))&L.pwm_lambda(pwm)<1-1e-6), ...
                    'VariableNames',{'method','seed','window','control_samples','scaled_count','scaled_duration_s','longest_episode_s', ...
                    'lambda_min','high_priority_fallback_count','engineering_fallback_count','pwm_events','pwm_scaled_count'})];
            end
            active=find(L.mode~=0|(isfinite(L.lambda)&L.lambda<1-1e-6));
            indices=unique([keep(:);active;max(1,active-1);min(numel(t),active+1)]);
            trace=[trace;table(repmat(method,numel(indices),1),repmat(seed,numel(indices),1),t(indices),L.lambda(indices),L.beta(indices),L.mode(indices), ...
                'VariableNames',{'method','seed','time_s','lambda','beta','mode'})];
            if ~isempty(active)
                count=numel(active);events=[events;table(repmat(method,count,1),repmat(seed,count,1),repmat("control",count,1), ...
                    t(active),L.lambda(active),L.beta(active),L.mode(active),t(active)>=6&t(active)<=50, ...
                    'VariableNames',{'method','seed','event_kind','time_s','lambda','beta','mode','in_task_window'})];
            end
            active=find(L.pwm_mode~=0|(isfinite(L.pwm_lambda)&L.pwm_lambda<1-1e-6));
            if ~isempty(active)
                count=numel(active);events=[events;table(repmat(method,count,1),repmat(seed,count,1),repmat("pwm",count,1), ...
                    L.pwm_update_time_s(active),L.pwm_lambda(active),NaN(count,1),L.pwm_mode(active), ...
                    L.pwm_update_time_s(active)>=6&L.pwm_update_time_s(active)<=50, ...
                    'VariableNames',{'method','seed','event_kind','time_s','lambda','beta','mode','in_task_window'})];
            end
        else
            assert(~any(isfinite(L.lambda)),'非PCA不得伪造优先级系数。');
        end
        log_name=sprintf('%s_s%d.mat',method,seed);fid=fopen(fullfile(folder,'logs',log_name),'rb');assert(fid>=0);
        bytes=fread(fid,Inf,'*uint8');fclose(fid);
        verified_files(end+1)=struct('path',"logs/"+string(log_name),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
        clear d L bytes
    end
end
if isempty(events),events=table(string.empty(0,1),zeros(0,1),string.empty(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
    'VariableNames',{'method','seed','event_kind','time_s','lambda','beta','mode','in_task_window'});end
writetable(checks_all,fullfile(folder,'independent_run_checks.csv'));writetable(activation,fullfile(folder,'priority_activation.csv'));
writetable(trace,fullfile(folder,'priority_trace.csv'));writetable(events,fullfile(folder,'priority_events.csv'));
report=struct('scenario_id',scenario,'formal_logs_verified',15,'state_metric_rows_verified',720, ...
    'maximum_csv_error',maximum_csv_error,'maximum_metric_error',maximum_metric_error,'common_inputs_regenerated_and_verified',true, ...
    'engine_matches_recorded_run',true,'engine_fingerprint',engine,'frozen_protocol_hash',hash,'runtime_truth_audit_recorded',true, ...
    'verified_log_files',verified_files, ...
    'all_methods_meet_task_requirements',all(checks_all.run_task_passed),'independent_qualification_not_hover_gate',true);
fid=fopen(fullfile(folder,'independent_checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
fprintf('F8_INDEPENDENT_CHECKS_PASS %s: 15 logs,720 state metrics; allTask=%d\n',scenario,report.all_methods_meet_task_requirements);
end
