function report=f8_pressure_development_diagnostics(folder)
% 开发数据单列实际lambda、beta与回退；不把一个种子作为三种子确认。
ca_setup();P=readtable(fullfile(folder,'status.csv'),'TextType','string');assert(height(P)==9&&all(ismember(P.status,["completed","failed"])));
summary=table();trace=table();verified=struct('path',{},'sha256',{});
S=readtable(fullfile(folder,'task_metrics.csv'),'TextType','string');
for index=1:height(P)
    method=P.method(index);if P.status(index)~="completed",continue;end
    id=P.scenario_id(index);seed=P.seed(index);case_folder=fullfile(folder,id);
    path=fullfile(case_folder,'logs',sprintf('%s_s%d.mat',method,seed));d=load(path);L=d.L;
    [c,m,ref]=ca_f8_pressure_protocol(id,seed,2);
    assert(isequaln(c,d.c)&&isequaln(m,d.m)&&isequaln(ref,d.ref));
    assert(d.signature==allocation_comparison_hash({c,ref,ca_prepare_experiment(c,ref.time_s)}));
    [metric,check]=f8_evaluate_run(L,c,m,ref,d.protocol);row=S(S.method==method&S.scenario_id==id&S.seed==seed,:);assert(height(row)==1);
    assert(logical(row.run_task_passed)==check.run_task_passed&&logical(row.valid_data)==check.valid_data);
    for name=["horizontal_position_rmse_m","altitude_rmse_m","velocity_rmse_m_s","yaw_rmse_deg","inner_attitude_rmse_deg","estimator_attitude_rmse_deg"]
        assert(abs(row.(name)-metric.(name))<1e-10,'开发CSV与完整MAT不一致。');
    end
    fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    verified(end+1)=struct('path',string(fullfile(id,'logs',sprintf('%s_s%d.mat',method,seed))),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
    if ~startsWith(method,"PCA"),clear d L;continue;end
    t=d.ref.time_s;q=t>=6&t<=50;dt=1/d.c.sample_hz;
    scaled=L.mode(q)==0&isfinite(L.lambda(q))&L.lambda(q)<1-1e-6;
    beta=L.beta(q);beta=beta(isfinite(beta));minimum_beta=NaN;if ~isempty(beta),minimum_beta=min(beta);end
    lambda=L.lambda(q);lambda=lambda(isfinite(lambda));minimum_lambda=NaN;if ~isempty(lambda),minimum_lambda=min(lambda);end
    G=readtable(fullfile(case_folder,sprintf('priority_geometry_%s_s%d.csv',method,seed)));
    certificate=G.static_priority_certificate;high=G.static_high_feasible;
    if method=="PCA_PREDICTIVE",certificate=G.dynamic_priority_certificate;high=G.dynamic_high_feasible;end
    summary=[summary;table(id,method,seed,sum(q),sum(scaled)*dt,minimum_lambda,sum(L.mode(q)==1)*dt,minimum_beta,sum(L.mode(q)==2)*dt, ...
        sum(certificate)*dt,100*mean(high),100*mean(G.vh_vc_angle_deg>=15), ...
        'VariableNames',{'scenario_id','method','seed','main_control_samples','normal_scaled_duration_s','lambda_min', ...
        'high_priority_fallback_duration_s','beta_min','engineering_fallback_duration_s','nominal_geometry_certificate_duration_s', ...
        'nominal_high_priority_feasible_percent','vh_vc_angle_ge15_percent'})];
    active=find(L.mode~=0|(isfinite(L.lambda)&L.lambda<1-1e-6));keep=unique([(1:8:numel(t))';active;max(1,active-1);min(numel(t),active+1)]);
    count=numel(keep);trace=[trace;table(repmat(id,count,1),repmat(method,count,1),repmat(seed,count,1),t(keep),L.lambda(keep),L.beta(keep),L.mode(keep), ...
        'VariableNames',{'scenario_id','method','seed','time_s','lambda','beta','mode'})];
    clear d L G
end
writetable(summary,fullfile(folder,'development_priority_summary.csv'));writetable(trace,fullfile(folder,'development_priority_trace.csv'));
report=struct('development_runs_attempted',9,'development_runs_completed',sum(P.status=="completed"), ...
    'development_runs_failed',sum(P.status=="failed"),'development_seed',9002,'PCA_runs_audited',height(summary),'independent_confirmation',false, ...
    'missing_lambda_or_beta_not_filled_with_one',true,'nominal_certificate_not_actual_plant_feasibility_proof',true, ...
    'completed_run_inputs_and_metrics_independently_verified',true,'verified_log_files',verified);
fid=fopen(fullfile(folder,'development_priority_checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fprintf('F8_PRESSURE_DEVELOPMENT_AUDIT_PASS 9 attempts,%d completed,%d failed,%d PCA logs\n', ...
    report.development_runs_completed,report.development_runs_failed,report.PCA_runs_audited);
end
