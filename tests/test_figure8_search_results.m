function report=test_figure8_search_results(folder)
% 独立从完整日志核对动态失配、十二状态及实际优先级触发，不重跑仿真。
ca_setup();P=readtable(fullfile(folder,'status.csv'),'TextType','string');
S=readtable(fullfile(folder,'summary.csv'),'TextType','string');M=readtable(fullfile(folder,'state_metrics.csv'),'TextType','string');
protocol=jsondecode(fileread(fullfile(folder,'protocol.json')));
assert(height(P)==15&&all(P.status=="completed")&&height(S)==60&&height(M)==720);
assert(strcmp(protocol.engine_fingerprint,allocation_comparison_engine(ca_setup())));
methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];
trace=table();activation=table();events=table();maximum_error=0;minimum_model_error=Inf;
for seed=1:3
    signature="";
    for method=methods
        d=load(fullfile(folder,'logs',sprintf('%s_s%d.mat',method,seed)));L=d.L;t=d.ref.time_s;
        assert(string(L.name)==method&&d.c.estimator_mode=="lite"&&d.model.command_limit_deg==40);
        assert(isequal(d.c.tau_actual_s,0.001*[24;27;30;33;36;40])&&isequal(d.c.tau_model_s,0.03*ones(6,1)));
        assert(~isfield(ca_allocator_config(d.c),'tau_actual_s')&&~any(L.table_extrapolated));
        if strlength(signature)==0,signature=d.signature;end
        assert(signature==d.signature&&allocation_comparison_hash(d.ref)==string(protocol.reference_hash));
        expected=[d.ref.position_ned_m,d.ref.velocity_ned_m_s,rad2deg(L.desired_euler_rad),rad2deg(L.omega_reference_rad_s)];
        actual=[L.position_ned_m,L.velocity_ned_m_s,rad2deg(L.euler_rad),rad2deg(L.omega_rad_s)];
        error=actual-expected;error(:,7:9)=rad2deg(atan2(sin(deg2rad(error(:,7:9))),cos(deg2rad(error(:,7:9)))));
        T=readtable(fullfile(folder,'tracks',sprintf('%s_s%d.csv',method,seed)));keep=1:8:numel(t);
        assert(max(abs(T.time_s-t(keep)))<1e-12);
        for j=1:12
            assert(max(abs(T.("target_"+names(j))-expected(keep,j)))<1e-10);
            assert(max(abs(T.("actual_"+names(j))-actual(keep,j)))<1e-10);
        end
        bounds=[0,52;6,50;8,48;0,6];windows=["whole","task","cruise","transient"];
        for wi=1:4
            q=t>=bounds(wi,1)&t<=bounds(wi,2);e=L.pwm_update_time_s>=bounds(wi,1)&L.pwm_update_time_s<=bounds(wi,2);
            row=S(S.method==method&S.seed==seed&S.window==windows(wi),:);assert(height(row)==1);
            for j=1:12
                r=M(M.method==method&M.seed==seed&M.window==windows(wi)&M.state==names(j),:);assert(height(r)==1);
                difference=abs(sqrt(mean(error(q,j).^2))-r.rmse);maximum_error=max(maximum_error,difference);assert(difference<1e-10);
            end
            assert(abs(max(rad2deg(L.rotation_error_rad(q)))-row.attitude_peak_deg)<1e-10);
            sat=100*mean(any(abs(rad2deg(L.pwm_command_rad(e,:)))>=40-1e-5,2));assert(abs(sat-row.saturation_percent)<1e-10);
            delta=sqrt(mean(rad2deg(L.estimated_delta_rad(q,:)-L.actual_delta_rad(q,:)).^2,'all'));
            assert(abs(delta-row.actuator_estimate_rmse_deg)<1e-10);
            if windows(wi)=="task",minimum_model_error=min(minimum_model_error,delta);end
            if startsWith(method,"PCA")
                a=L.lambda(q);finite=isfinite(a);minimum=NaN;if any(finite),minimum=min(a(finite));end
                activation=[activation;table(method,seed,windows(wi),sum(q),sum(L.mode(q)==0&finite&a<1-1e-6),minimum, ...
                    sum(L.mode(q)==1),sum(L.mode(q)==2),sum(e),sum(L.pwm_mode(e)==0&isfinite(L.pwm_lambda(e))&L.pwm_lambda(e)<1-1e-6), ...
                    'VariableNames',{'method','seed','window','control_samples','scaled_count','lambda_min','mode1_count','mode2_count','pwm_events','pwm_scaled_count'})];
            else
                assert(~any(isfinite(L.lambda)),'非PCA不得伪造优先级系数。');
            end
        end
        if startsWith(method,"PCA")
            active=find(L.mode~=0|(isfinite(L.lambda)&L.lambda<1-1e-6));
            indices=unique([keep(:);active;max(1,active-1);min(numel(t),active+1)]);
            trace=[trace;table(repmat(method,numel(indices),1),repmat(seed,numel(indices),1),t(indices),L.lambda(indices),L.beta(indices),L.mode(indices), ...
                'VariableNames',{'method','seed','time_s','lambda','beta','mode'})];
            for i=reshape(active,1,[])
                events=[events;table(method,seed,"control",t(i),L.lambda(i),L.beta(i),L.mode(i),t(i)>=6&&t(i)<=50, ...
                    'VariableNames',{'method','seed','event_kind','time_s','lambda','beta','mode','in_task_window'})];
            end
            active=find(L.pwm_mode~=0|(isfinite(L.pwm_lambda)&L.pwm_lambda<1-1e-6));
            for i=reshape(active,1,[])
                events=[events;table(method,seed,"pwm",L.pwm_update_time_s(i),L.pwm_lambda(i),NaN,L.pwm_mode(i), ...
                    L.pwm_update_time_s(i)>=6&&L.pwm_update_time_s(i)<=50, ...
                    'VariableNames',{'method','seed','event_kind','time_s','lambda','beta','mode','in_task_window'})];
            end
        end
    end
end
assert(minimum_model_error>1e-8,'动态失配实验不应仍是完全精确舵角估计。');
C=allocation_comparability(S,P);gate_file='comparability.csv';
descriptive=isfield(protocol,'evaluation_policy')&&string(protocol.evaluation_policy)=="trajectory_descriptive_v2";
if descriptive,gate_file='legacy_hover_comparability.csv';end
saved=readtable(fullfile(folder,gate_file),'TextType','string');
assert(isequal(string(C.comparability),saved.comparability));
writetable(trace,fullfile(folder,'priority_trace.csv'));writetable(activation,fullfile(folder,'priority_activation.csv'));
if isempty(events),events=table(string.empty(0,1),zeros(0,1),string.empty(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),false(0,1), ...
    'VariableNames',{'method','seed','event_kind','time_s','lambda','beta','mode','in_task_window'});end
writetable(events,fullfile(folder,'priority_events.csv'));
report=struct('logs_verified',15,'state_metric_rows_verified',720,'maximum_csv_error',maximum_error, ...
    'minimum_task_actuator_estimate_rmse_deg',minimum_model_error,'engine_matches_recorded_run',true, ...
    'lite_velocity_aiding_enabled',protocol.lite_velocity_aiding_enabled, ...
    'true_tau_ms',[24,27,30,33,36,40],'estimator_tau_ms',30,'parameters_calibrated',false, ...
    'legacy_hover_comparability',string(C.comparability),'task_qualification_inferred_from_hover_gates',false);
fid=fopen(fullfile(folder,'independent_checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
fprintf('FIG8_SEARCH_RESULTS_PASS 15 logs, 720 state metrics; legacy_hover_classification_only=%s\n',C.comparability);
end
