function study=hdt_run(output_tag)
% 固定501预测PCA一次运行，异常和门槛失败都保留，不自动重试或扩批。
root=ca_setup();assert(~isempty(regexp(char(output_tag),'^[A-Za-z0-9_-]+$','once')));
tag=string(output_tag);out=fullfile(root,'results','hover_distance_takeoff_precheck_'+tag);
wtr_dir=fullfile(root,'logs','wtr','precheck_'+tag);figures=fullfile(root,'figures','hover_distance_takeoff_precheck_'+tag);
assert(~isfolder(out)&&~isfolder(wtr_dir)&&~isfolder(figures),'拒绝覆盖任一既有交付目录。');
[cfg,model,ref,plan,spec]=hdt_config();sources=hdt_sources(root);
experiment=ppid_noise(cfg,ref,plan);experiment.disturbance_series=cfg.disturbance_series;
signature=allocation_comparison_hash({cfg,model,ref,experiment,plan});
mkdir(out);mkdir(fullfile(out,'logs'));mkdir(fullfile(out,'inputs'));mkdir(fullfile(out,'failures'));mkdir(wtr_dir);
diary(fullfile(out,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
copyfile(fullfile(root,'research','hover_distance_takeoff_20261103','protocol.json'),fullfile(out,'takeoff_protocol.json'));
write_json(fullfile(out,'sources.json'),sources);
write_json(fullfile(out,'source_lock.json'),struct('created_before_flight',true,'sources',sources,'input_signature_including_plan',signature));
save(fullfile(out,'inputs','seed501.mat'),'cfg','model','ref','plan','spec','experiment','signature','-v7');
status=table("PCA_PREDICTIVE",501,"running","",'VariableNames',{'method','seed','status','error_id'});
writetable(status,fullfile(out,'status.csv'));
provenance=table("PCA_PREDICTIVE",501,string(signature),'VariableNames',{'method','seed','input_signature_including_plan'});
writetable(provenance,fullfile(out,'provenance.csv'));
fprintf('TAKEOFF_PREFLIGHT duration=50 seed=501 method=PCA_PREDICTIVE input=%s engine=%s\n',signature,sources.base.parent.engine);
fprintf('TAKEOFF_REFERENCE peak_speed=%.9gm_s peak_accel=%.9gm_s2 pwm_capacity=%d expected=%d\n', ...
    max(vecnorm(ref.velocity_ned_m_s,2,2)),max(vecnorm(ref.acceleration_ned_m_s2,2,2)),spec.pwm_buffer_capacity,spec.expected_pwm_events);
path=fullfile(out,'logs','PCA_PREDICTIVE_s501.mat');flight_completed=false;passed=false;
try
    assert(isequaln(hdt_sources(root),sources));
    L=ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",experiment,plan);
    flight_completed=true;L.ekf_rate_hz=(sum(L.estimator_updated)-1)/50;
    L.hover_distance_spec=spec;L.actual_duration_s=50;
    save(path,'L','cfg','model','ref','plan','spec','signature','-v7');
    [metrics,checks]=hdt_metrics(L,cfg,model,ref,plan);
    save(path,'metrics','checks','-append');writetable(struct2table(metrics,'AsArray',true),fullfile(out,'metrics.csv'));
    write_json(fullfile(out,'checks.json'),checks);passed=metrics.precheck_passed;
    if passed,status.status="completed";else,status.status="failed";status.error_id="takeoff:FeasibilityCheck";
        write_json(fullfile(out,'failures','PCA_PREDICTIVE_s501.json'),struct('identifier',status.error_id,'metrics',metrics));end
catch problem
    status.status="failed";status.error_id=string(problem.identifier);
    write_json(fullfile(out,'failures','PCA_PREDICTIVE_s501.json'), ...
        struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack,'flight_completed',flight_completed));
    fprintf('TAKEOFF_FAILED %s: %s\n',problem.identifier,problem.message);
end
assert(isequaln(hdt_sources(root),sources),'运行过程中来源改变。');
writetable(status,fullfile(out,'status.csv'));
write_json(fullfile(out,'completion.json'),struct('requested',1,'simulation_calls',1,'full_50s_log',flight_completed, ...
    'precheck_passed',passed,'formal_batch_launched',false,'parameters_retried',false));
% 后处理失败不触发重飞；完整MAT始终先保存。
if flight_completed&&isfile(fullfile(out,'metrics.csv'))
    executable=getenv('WINDTRACE_PYTHON');assert(~isempty(executable),'请指定带SciPy环境的WINDTRACE_PYTHON。');
    wtr=fullfile(wtr_dir,'PCA_PREDICTIVE_s501.wtr');export_windtrace_flight(path,wtr,executable);
    fprintf('TAKEOFF_WTR %s\n',wtr);
end
study=struct('output_dir',out,'wtr_dir',wtr_dir,'figures_dir',figures,'status',status,'precheck_passed',passed);
fprintf('TAKEOFF_FINISH full_50s=%d precheck=%d; NO_RETRY NO_FORMAL_BATCH\n',flight_completed,passed);
end

function write_json(path,value)
% 所有记录仅写新建批次目录。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
