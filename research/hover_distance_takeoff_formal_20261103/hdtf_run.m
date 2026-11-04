function study=hdtf_run(output_tag)
% 新协议一次预检加十五条正式运行；任何失败均保留，不重试、不修改参数。
root=ca_setup();
for rel=["research/ppid_pindi","research/hover_distance","research/hover_distance_takeoff_20261103"]
    addpath(fullfile(root,rel));
end
assert(~isempty(regexp(char(output_tag),'^[A-Za-z0-9_-]+$','once')));
tag=string(output_tag);batch="hover_distance_takeoff_formal_"+tag;
out=fullfile(root,'results',batch);pre=fullfile(root,'results',"hover_distance_takeoff_final_precheck_"+tag);
work=fullfile(root,'results',"hover_distance_takeoff_formal_work_"+tag);
wtr=fullfile(root,'logs','wtr',batch);pre_wtr=fullfile(root,'logs','wtr',"final_precheck_"+tag);
figures=fullfile(root,'figures',batch);
for path=[out,pre,work,wtr,pre_wtr,figures],assert(~isfolder(path),'拒绝覆盖既有目录：%s',path);end
capacity=jsondecode(fileread(fullfile(root,'results','ppid_capacity_fix_20261103_r1','final_checks.json')));
assert(capacity.passed,'容量修复未完成验收，禁止正式批。');
sources=hdtf_sources(root);p=jsondecode(fileread(fullfile(root,'research','hover_distance_takeoff_formal_20261103','protocol.json')));
methods=string(p.methods(:));seeds=p.seeds(:);assert(numel(methods)*numel(seeds)==15);
python=getenv('WINDTRACE_PYTHON');assert(isfile(python),'请指定带SciPy的WINDTRACE_PYTHON。');
for path=[out,pre],mkdir(path);mkdir(fullfile(path,'logs'));mkdir(fullfile(path,'inputs'));mkdir(fullfile(path,'failures'));end
mkdir(work);mkdir(wtr);mkdir(pre_wtr);
diary(fullfile(work,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
[~,head]=system('git rev-parse HEAD');[~,branch]=system('git branch --show-current');
branch_now=strtrim(string(branch));assert(ismember(branch_now,["hover_distance","change-B"]),'正式批只允许 hover_distance 或 change-B。');
write_json(fullfile(work,'git_start.json'),struct('head',strtrim(head),'branch',strtrim(branch),'commit_push',false));
inputs=cell(numel(seeds),1);signatures=strings(numel(seeds),1);
for j=1:numel(seeds)
    [cfg,model,ref,plan,spec]=hdtf_config(seeds(j));experiment=ppid_noise(cfg,ref,plan);experiment.disturbance_series=cfg.disturbance_series;
    signature=allocation_comparison_hash({cfg,model,ref,experiment,plan});signatures(j)=signature;
    inputs{j}=struct('cfg',cfg,'model',model,'ref',ref,'plan',plan,'spec',spec,'experiment',experiment,'signature',signature);
end
% 每个种子的输入只生成一次；预检与正式批读取同一份已冻结实现。
for j=1:numel(seeds)
    value=inputs{j};save(fullfile(out,'inputs',sprintf('seed%d.mat',seeds(j))),'-struct','value','-v7');
end
copyfile(fullfile(out,'inputs','seed501.mat'),fullfile(pre,'inputs','seed501.mat'));
for path=[out,pre]
    copyfile(fullfile(root,'research','hover_distance_takeoff_formal_20261103','protocol.json'),fullfile(path,'formal_protocol.json'));
    write_json(fullfile(path,'sources.json'),sources);
    write_json(fullfile(path,'source_lock.json'),struct('created_before_flight',true,'sources',sources,'seeds',seeds,'input_signatures_including_plan',signatures));
end
write_json(fullfile(work,'preflight.json'),struct('capacity_verified',true,'all_output_directories_new',true, ...
    'sources',sources,'input_signatures_including_plan',signatures,'methods',methods,'seeds',seeds,'protocol',p));
fprintf('HDTF_FREEZE duration=55 takeoff=12 main=[15,27) recovery=[27,37) filter=15/15 engine=%s\n',sources.base.parent.engine);
for j=1:3,fprintf('HDTF_INPUT seed=%d signature=%s roll_amplitude=%.12gNm\n',seeds(j),signatures(j),inputs{j}.spec.roll_disturbance_amplitude_nm);end
pre_status=make_status("PCA_PREDICTIVE",501,signatures(1));
writetable(pre_status,fullfile(pre,'status.csv'));writetable(pre_status(:,{'method','seed','input_signature_including_plan'}),fullfile(pre,'provenance.csv'));
[pre_status,pre_metrics,pre_checks]=run_one(pre,pre_wtr,pre_status,inputs{1},sources,root,python,true);
writetable(pre_status,fullfile(pre,'status.csv'));
passed=~isempty(pre_metrics)&&pre_metrics.precheck_passed&&pre_status.status=="completed";
write_json(fullfile(pre,'completion.json'),struct('simulation_calls',1,'precheck_passed',passed,'parameters_retried',false));
if ~passed
    fprintf('HDTF_STOP final-timeline precheck failed; NO_FORMAL_BATCH NO_RETRY\n');
    write_json(fullfile(work,'completion.json'),struct('precheck_passed',false,'formal_simulation_calls',0));
    study=struct('precheck_passed',false,'precheck_dir',pre,'output_dir',out);return;
end
fprintf('HDTF_PRECHECK_PASSED altitude12_true=%.9g settle_vz_true=%.9g lambda_duty=%.9g lambda_min=%.9g\n', ...
    pre_metrics.true_altitude_at_12s_m,pre_metrics.true_settle_vertical_speed_rmse_m_s,pre_metrics.lambda_scaled_duty,pre_metrics.normal_lambda_min);
assert(isequaln(hdtf_sources(root),sources));
write_json(fullfile(out,'formal_lock.json'),struct('frozen_before_formal_flights',true,'sources',sources,'protocol',p, ...
    'input_signatures_including_plan',signatures,'precheck_source',fullfile(pre,'logs','PCA_PREDICTIVE_s501.mat'), ...
    'precheck_mat_sha256',file_sha(fullfile(pre,'logs','PCA_PREDICTIVE_s501.mat')), ...
    'precheck_checks',pre_checks,'simulation_budget',15,'retries_allowed',false));
status=make_status(repmat(methods,numel(seeds),1),repelem(seeds,numel(methods)),repelem(signatures,numel(methods)));
writetable(status,fullfile(out,'status.csv'));writetable(status(:,{'method','seed','input_signature_including_plan'}),fullfile(out,'provenance.csv'));
metrics=pre_metrics([]);calls=0;
for k=1:height(status)
    j=find(seeds==status.seed(k));calls=calls+1;
    [row,m,~]=run_one(out,wtr,status(k,:),inputs{j},sources,root,python,false);status(k,:)=row;
    if ~isempty(m),metrics(end+1)=m;writetable(struct2table(metrics),fullfile(out,'metrics.csv'));end %#ok<AGROW>
    writetable(status,fullfile(out,'status.csv'));
    write_json(fullfile(work,'progress.json'),struct('simulation_calls',calls,'completed',sum(status.status=="completed"), ...
        'failed',sum(status.status=="failed"),'last_method',row.method,'last_seed',row.seed));
end

function value=file_sha(path)
% 记录已经保存的原始文件摘要，不重写文件。
fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
value=allocation_comparison_hash(bytes,true);
end
assert(calls==15&&isequaln(hdtf_sources(root),sources));
write_json(fullfile(out,'completion.json'),struct('requested',15,'simulation_calls',calls,'completed',sum(status.status=="completed"), ...
    'failed',sum(status.status=="failed"),'wtr_exported',sum(status.wtr_status=="completed"),'precheck_passed',passed, ...
    'all_recorded_data_valid',~isempty(metrics)&&all([metrics.data_valid]),'parameters_retried',false,'old_locks_modified',false));
write_json(fullfile(work,'completion.json'),struct('precheck_passed',true,'formal_simulation_calls',calls,'sources_unchanged',true));
study=struct('precheck_passed',true,'precheck_dir',pre,'output_dir',out,'wtr_dir',wtr,'figures_dir',figures,'status',status);
fprintf('HDTF_FINISH completed=%d/15 failures=%d WTR=%d NO_COMMIT NO_PUSH\n',sum(status.status=="completed"),sum(status.status=="failed"),sum(status.wtr_status=="completed"));
end

function status=make_status(method,seed,signature)
% 状态表先于运行落盘，以便交付物关联原始审计记录。
method=string(method(:));seed=seed(:);signature=string(signature(:));n=numel(method);
status=table(method,seed,repmat("not_run",n,1),repmat("",n,1),signature,repmat("not_run",n,1), ...
    'VariableNames',{'method','seed','status','error_id','input_signature_including_plan','wtr_status'});
end

function [status,metrics,checks]=run_one(out,wtr,status,input,sources,root,python,is_precheck)
% 先保存完整MAT，再审计、导出；后处理异常不会触发重飞。
cfg=input.cfg;model=input.model;ref=input.ref;plan=input.plan;spec=input.spec;experiment=input.experiment;signature=input.signature;
method=status.method;seed=status.seed;path=fullfile(out,'logs',sprintf('%s_s%d.mat',method,seed));assert(~isfile(path));
metrics=[];checks=[];full_log=false;assert(isequaln(hdtf_sources(root),sources));
fprintf('HDTF_RUN precheck=%d %s seed%d\n',is_precheck,method,seed);status.status="running";
try
    L=ppid_simulate(cfg,model,ref,method,experiment,plan);full_log=true;L.hover_distance_spec=spec;L.actual_duration_s=ref.time_s(end);
    save(path,'L','cfg','model','ref','plan','spec','signature','-v7');
    [metrics,checks]=hdtf_metrics(L,cfg,model,ref,plan,seed);save(path,'metrics','checks','-append');
    assert(metrics.data_valid,'hdtf:InvalidData','完整日志未通过有限性或气动有效性核验。');
    if is_precheck,assert(metrics.precheck_passed,'hdtf:PrecheckFailed','最终时间线起飞预检未通过，不启动正式批。');end
    status.status="completed";
    write_json(fullfile(out,sprintf('checks_%s_s%d.json',method,seed)),checks);
    if is_precheck,writetable(struct2table(metrics),fullfile(out,'metrics.csv'));end
catch problem
    status.status="failed";status.error_id=string(problem.identifier);
    write_json(fullfile(out,'failures',sprintf('%s_s%d.json',method,seed)), ...
        struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack,'full_55s_log_saved',full_log,'retried',false));
    fprintf('HDTF_FAILED %s seed%d %s: %s\n',method,seed,problem.identifier,problem.message);
end
% 单条状态先写侧车，导出器从已保存的审计状态读取，不更改飞行数据。
status_path=fullfile(out,'status.csv');all_status=readtable(status_path,'TextType','string');
all_status.error_id=string(all_status.error_id);all_status.error_id(ismissing(all_status.error_id)|all_status.error_id=="NaN")="";
q=all_status.method==method&all_status.seed==seed;all_status(q,:)=status;writetable(all_status,status_path);
if full_log&&~isempty(checks)
    try
        export_windtrace_flight(path,fullfile(wtr,sprintf('%s_s%d.wtr',method,seed)),python);status.wtr_status="completed";
    catch problem
        status.wtr_status="failed";
        write_json(fullfile(out,'failures',sprintf('export_%s_s%d.json',method,seed)), ...
            struct('identifier',problem.identifier,'message',problem.message,'simulation_retried',false));
        fprintf('HDTF_EXPORT_FAILED %s seed%d: %s\n',method,seed,problem.message);
    end
end
assert(isequaln(hdtf_sources(root),sources),'冻结后源码改变。');
fprintf('HDTF_DONE %s seed%d status=%s wtr=%s full_log=%d\n',method,seed,status.status,status.wtr_status,full_log);
end

function write_json(path,value)
% 仅更新本次新建批次的运行记录。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
