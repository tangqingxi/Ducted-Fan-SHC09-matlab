function study=hdtfr_resume()
% 只恢复汇总中断并运行十四条未运行项；不改原冻结驱动，不重飞已完成记录。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'),fullfile(root,'research','hover_distance'), ...
    fullfile(root,'research','hover_distance_takeoff_20261103'),fullfile(root,'research','hover_distance_takeoff_formal_20261103'));
batch='hover_distance_takeoff_formal_20261103_r1';out=fullfile(root,'results',batch);wtr=fullfile(root,'logs','wtr',batch);
work=fullfile(root,'results','hover_distance_takeoff_formal_work_20261103_r1','summary_recovery');assert(~isfolder(work));mkdir(work);
diary(fullfile(work,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
copyfile(fullfile(out,'status.csv'),fullfile(work,'status.before.csv'));
sources=jsondecode(fileread(fullfile(out,'sources.json')));current=hdtf_sources(root);
assert(isequaln(jsondecode(jsonencode(current)),sources),'原冻结数值来源已变，禁止续跑。');
opts=detectImportOptions(fullfile(out,'status.csv'),'TextType','string');
opts=setvartype(opts,{'method','status','error_id','input_signature_including_plan','wtr_status'},'string');
status=readtable(fullfile(out,'status.csv'),opts);status.error_id(ismissing(status.error_id)|status.error_id=="NaN")="";
assert(height(status)==15&&sum(status.status=="completed")==1&&sum(status.status=="not_run")==14);
assert(status.method(1)=="DA_NS"&&status.seed(1)==501&&status.status(1)=="completed");
saved=load(fullfile(out,'logs','DA_NS_s501.mat'),'metrics','checks');metrics=saved.metrics;
assert(saved.checks.data_valid&&saved.checks.command_bounds_passed&&isfile(fullfile(wtr,'DA_NS_s501.wtr')));
status.wtr_status(1)="completed";writetable(status,fullfile(out,'status.csv'));writetable(struct2table(metrics),fullfile(out,'metrics.csv'));
self=mfilename('fullpath')+".m";self_sha=file_sha(self);lock_sha=file_sha(fullfile(out,'formal_lock.json'));
write_json(fullfile(work,'administrative_exception.json'),struct('reason','Summary accumulator initialized as fieldless struct; first successful metrics assignment failed.', ...
    'original_error','Subscripted assignment between dissimilar structures at hdtf_run line64.', ...
    'completed_simulations_before_interruption',1,'remaining_not_run',14,'completed_DA_NS_s501_rerun',false, ...
    'precheck_rerun',false,'numerical_sources_changed',false,'gates_or_parameters_changed',false, ...
    'original_frozen_driver_sha256',file_sha(fullfile(root,'research','hover_distance_takeoff_formal_20261103','hdtf_run.m')), ...
    'formal_lock_sha256_unchanged',lock_sha,'recovery_driver_sha256',self_sha, ...
    'policy','Only management recovery; initialize accumulator from saved metrics, then run not_run rows once. Preserve original sources, locks, MAT, WTR and logs.'));
python=getenv('WINDTRACE_PYTHON');assert(isfile(python));calls=0;
for k=find(status.status=="not_run")'
    input=load(fullfile(out,'inputs',sprintf('seed%d.mat',status.seed(k))));
    assert(input.signature==status.input_signature_including_plan(k));
    assert(isequaln(hdtf_sources(root),current)&&file_sha(self)==self_sha&&file_sha(fullfile(out,'formal_lock.json'))==lock_sha);
    cfg=input.cfg;model=input.model;ref=input.ref;plan=input.plan;spec=input.spec;signature=input.signature;
    method=status.method(k);seed=status.seed(k);path=fullfile(out,'logs',sprintf('%s_s%d.mat',method,seed));artifact=fullfile(wtr,sprintf('%s_s%d.wtr',method,seed));
    assert(~isfile(path)&&~isfile(artifact),'只补从未运行的记录，拒绝覆盖。');calls=calls+1;full_log=false;m=[];checks=[];
    status.status(k)="running";writetable(status,fullfile(out,'status.csv'));fprintf('HDTFR_RUN %s seed%d call%d/14\n',method,seed,calls);
    try
        L=ppid_simulate(cfg,model,ref,method,input.experiment,plan);full_log=true;L.hover_distance_spec=spec;L.actual_duration_s=ref.time_s(end);
        save(path,'L','cfg','model','ref','plan','spec','signature','-v7');
        [m,checks]=hdtf_metrics(L,cfg,model,ref,plan,seed);
        % 保存字段名与原驱动一致，避免导出层读取到工作区汇总数组。
        one=struct('metrics',m,'checks',checks);save(path,'-struct','one','-append');
        assert(m.data_valid,'hdtf:InvalidData','完整日志数据无效。');status.status(k)="completed";
        write_json(fullfile(out,sprintf('checks_%s_s%d.json',method,seed)),checks);
    catch problem
        status.status(k)="failed";status.error_id(k)=string(problem.identifier);
        write_json(fullfile(out,'failures',sprintf('%s_s%d.json',method,seed)), ...
            struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack,'full_55s_log_saved',full_log,'retried',false));
        fprintf('HDTFR_FAILED %s seed%d %s\n',method,seed,problem.message);
    end
    if ~isempty(m),metrics(end+1)=m;writetable(struct2table(metrics),fullfile(out,'metrics.csv'));end %#ok<AGROW>
    writetable(status,fullfile(out,'status.csv'));
    if full_log&&~isempty(checks)
        try
            export_windtrace_flight(path,artifact,python);status.wtr_status(k)="completed";
        catch problem
            status.wtr_status(k)="failed";
            write_json(fullfile(out,'failures',sprintf('export_%s_s%d.json',method,seed)), ...
                struct('identifier',problem.identifier,'message',problem.message,'simulation_retried',false));
            fprintf('HDTFR_EXPORT_FAILED %s seed%d %s\n',method,seed,problem.message);
        end
    end
    writetable(status,fullfile(out,'status.csv'));
    write_json(fullfile(work,'progress.json'),struct('new_simulation_calls',calls,'total_formal_simulation_calls',calls+1, ...
        'completed',sum(status.status=="completed"),'failed',sum(status.status=="failed"),'last_method',method,'last_seed',seed));
    fprintf('HDTFR_DONE %s seed%d status=%s WTR=%s total=%d/15\n',method,seed,status.status(k),status.wtr_status(k),calls+1);
end
assert(calls==14&&isequaln(hdtf_sources(root),current)&&file_sha(self)==self_sha&&file_sha(fullfile(out,'formal_lock.json'))==lock_sha);
write_json(fullfile(out,'completion.json'),struct('requested',15,'simulation_calls',calls+1,'completed',sum(status.status=="completed"), ...
    'failed',sum(status.status=="failed"),'wtr_exported',sum(status.wtr_status=="completed"),'precheck_passed',true, ...
    'all_recorded_data_valid',numel(metrics)==15&&all([metrics.data_valid]),'parameters_retried',false, ...
    'management_resume_used',true,'original_frozen_sources_and_lock_unchanged',true,'completed_flights_rerun',0));
write_json(fullfile(work,'completion.json'),struct('new_simulation_calls',calls,'total_formal_calls',15,'completed_flights_rerun',0,'sources_unchanged',true));
study=struct('output_dir',out,'status',status);fprintf('HDTFR_FINISH completed=%d/15 WTR=%d NO_RETRY NO_COMMIT NO_PUSH\n',sum(status.status=="completed"),sum(status.wtr_status=="completed"));
end

function value=file_sha(path)
% 摘要原始字节；旧冻结文件只读。
fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);value=allocation_comparison_hash(bytes,true);
end

function write_json(path,value)
% 只写本次新批的管理记录，不修改协议与锁。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
