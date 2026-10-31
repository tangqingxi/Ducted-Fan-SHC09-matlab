function study = allocation_comparison_run(plan,out,options)
% 比较与负载扫描共用数值调度；逐项保存，失败如实继续，不改变任何模型或反馈。
root=ca_setup();assert(usejava('jvm'),'比较缓存摘要需要MATLAB默认JVM，请勿使用-nojvm。');assert(~isfolder(out),'禁止覆盖已有比较目录。');mkdir(out);mkdir(fullfile(out,'logs'));mkdir(fullfile(out,'failures'));
cache_dir=fullfile(root,'results','allocation_comparison_cache');if ~isfolder(cache_dir),mkdir(cache_dir);end
gates=struct('created_before_first_run',string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
 'required_methods',5,'max_saturation_percent',10,'max_attitude_peak_deg',5,'max_lite_attitude_rmse_deg',2,'aero_extrapolation',0, ...
 'aggregation',"所有请求方法和种子的主窗最坏值",'gate_source_hash',allocation_comparison_hash(fileread(fullfile(root,'analysis','allocation_comparability.m'))));
fid=fopen(fullfile(out,'predefined_gates.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(gates,PrettyPrint=true));fclose(fid);
engine=allocation_comparison_engine(root);reuse=string(options.reuse_from);
if strlength(reuse)>0
 resolved=string(java.io.File(char(reuse)).getCanonicalPath());base=string(java.io.File(fullfile(root,'results')).getCanonicalPath());
 assert(isfolder(resolved)&&startsWith(lower(resolved),lower(base)+filesep),'重放来源必须在本仓库results。');reuse=resolved;
end
plan.status=repmat("not_run",height(plan),1);plan.error_id=repmat("",height(plan),1);plan.error_message=repmat("",height(plan),1);
plan.aero_extrapolated=false(height(plan),1);plan.log_key=repmat("",height(plan),1);
S=allocation_comparison_empty_summary();provenance=table();previous="";prepared=false;
for index=1:height(plan)
 rowplan=plan(index,:);fprintf('比较 %s/%.0f%%/%s/seed%d/%s，%g秒\n',rowplan.case_id,100*rowplan.load_fraction,rowplan.estimator_mode,rowplan.seed,rowplan.method,rowplan.duration_s);
 loaded=false;origin="";audit="";input_signature="";
 try
  group=rowplan.case_id+"_"+rowplan.load_fraction+"_"+rowplan.estimator_mode+"_"+rowplan.seed+"_"+rowplan.duration_s;
  if group~=previous||~prepared
   prepared=false;
   [base,m,r,~,protocol,cases]=ca_mismatch_protocol(rowplan.duration_s,rowplan.load_fraction,"load_hold");
   item=cases(string({cases.id})==rowplan.case_id);c=base;c.estimator_mode=rowplan.estimator_mode;c.navigation_mode="ideal";
   c.vane_gain_scale=item.gains;c.vane_deflection_map=string(item.mapping);c.vane_saturation_deg=item.saturation_deg;
   for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"],c.(field)=c.(field)+rowplan.seed-1;end
   c.save_results=false;c.save_figures=false;c.show_figures=false;c=ca_validate_config(c);
   assert(c.aero_extrapolation_policy=="error"&&isequaln(ca_model(c),m)&&isequaln(ca_allocator_config(c),ca_allocator_config(base)),'ca:TruthLeak','私有失配进入分配器。');
   e=ca_prepare_experiment(c,r.time_s);input_signature=allocation_comparison_hash({c,r,e});previous=group;prepared=true;
  else,input_signature=allocation_comparison_hash({c,r,e});end
  key=rowplan.case_id+'_'+rowplan.estimator_mode+'_s'+rowplan.seed+'_'+rowplan.method+'_'+allocation_comparison_hash({engine,c,r,rowplan.method});plan.log_key(index)=key;
  target=fullfile(out,'logs',key+'.mat');cache=fullfile(cache_dir,key+'.mat');candidates=string.empty;
  if strlength(reuse)>0,candidates(end+1)=fullfile(reuse,'logs',key+'.mat');end
  if options.use_cached,candidates(end+1)=cache;end
  for candidate=candidates
   if ~isfile(candidate),continue;end
   origin=candidate;
   saved=load(candidate,'L','c','r','audit','engine_fingerprint','log_key');
   assert(isfield(saved,'engine_fingerprint')&&saved.engine_fingerprint==engine&&isfield(saved,'log_key')&&saved.log_key==key&&isequaln(saved.c,c)&&isequaln(saved.r,r),'ca:ComparisonCacheMismatch','缓存来源、配置或参考不一致。');
   assert(isfield(saved,'audit')&&(rowplan.estimator_mode=="ideal"||saved.audit=="verified_absent"),'ca:ComparisonTopicAudit','缓存缺少lite真值隔离核验。');
   L=saved.L;audit=saved.audit;loaded=true;origin=candidate;break;
  end
  if ~loaded
   L=ca_simulate(m,c,r,rowplan.method,e);L.time_for_metrics=r.time_s;audit="oracle_expected";
   if rowplan.estimator_mode=="lite"
    assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'),'ca:ComparisonTopicAudit','lite出现真值topic。');audit="verified_absent";
   end
   L=rmfield(L,'topic_log');origin=string(target);
  end
  assert(~any(L.table_extrapolated),'ca:AeroTableDomain','控制采样发生气动越界。');
  engine_fingerprint=engine;log_key=key;save(target,'L','c','r','audit','engine_fingerprint','log_key','-v7');
  if ~isfile(cache)
   pending=string(tempname(cache_dir))+'.mat';copyfile(target,pending);
   if ~isfile(cache),movefile(pending,cache);end
  end
  bounds=[0,rowplan.duration_s;protocol.evaluation_window_s;0,min(6,rowplan.duration_s)];windows=["whole","task","transient"];
  rows=table();
  for k=1:3
   metric=estimator_feedback_metrics_row(L,m,rowplan.case_id,rowplan.estimator_mode,rowplan.seed,windows(k),bounds(k,:));
   q=L.time_for_metrics>=bounds(k,1)&L.time_for_metrics<=bounds(k,2);
   metric.attitude_peak_deg=max(rad2deg(L.rotation_error_rad(q)));
   metric.position_peak_m=max(vecnorm(L.position_ned_m(q,:)-L.position_reference_ned_m(q,:),2,2));
   metric.aero_extrapolated_count=sum(L.table_extrapolated);metric.load_fraction=rowplan.load_fraction;metric.smoke_test=rowplan.smoke_test;
   rows=[rows;metric];
  end
  S=[S;rows];plan.status(index)="completed";
 catch problem
  plan.status(index)="failed";plan.error_id(index)=string(problem.identifier);plan.error_message(index)=string(problem.message);
  plan.aero_extrapolated(index)=strcmp(problem.identifier,'ca:AeroTableDomain');
  failure=struct('plan',table2struct(rowplan),'identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
  fid=fopen(fullfile(out,'failures',sprintf('%04d.json',index)),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(failure,PrettyPrint=true));fclose(fid);
 end
 provenance=[provenance;table(rowplan.case_id,rowplan.load_fraction,rowplan.estimator_mode,rowplan.seed,rowplan.method,plan.status(index),origin,loaded,audit,input_signature,engine, ...
 'VariableNames',{'case_id','load_fraction','estimator_mode','seed','method','status','origin','loaded','topic_check','input_signature','engine_fingerprint'})];
 if plan.status(index)=="failed"&&options.fail_fast
  if index<height(plan),plan.error_message(index+1:end)="fail_fast后未运行";end
  write_progress();break;
 end
 write_progress();
end
C=allocation_comparability(S,plan);writetable(C,fullfile(out,'comparability.csv'),'Encoding','UTF-8');
study=struct('output_dir',out,'summary',S,'comparability',C,'status',plan,'provenance',provenance,'completed',all(plan.status=="completed"),'engine_fingerprint',engine);
save(fullfile(out,'study.mat'),'study','-v7');
 function write_progress()
  writetable(plan,fullfile(out,'status.csv'),'Encoding','UTF-8');
  writetable(S,fullfile(out,'summary.csv'),'Encoding','UTF-8');
  writetable(provenance,fullfile(out,'provenance.csv'),'Encoding','UTF-8');
  current=allocation_comparability(S,plan);writetable(current,fullfile(out,'comparability.csv'),'Encoding','UTF-8');
 end
end
