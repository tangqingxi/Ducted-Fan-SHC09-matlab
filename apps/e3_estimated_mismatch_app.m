function study = e3_estimated_mismatch_app(varargin)
% 三工况、两反馈链的固定结构失配；任何运行失败记录后停止，不回退真值。
root=ca_setup();p=inputParser;
addParameter(p,'case_ids',["M0","M2b","M4"]);addParameter(p,'modes',["ideal","lite"]);
addParameter(p,'duration_s',20);addParameter(p,'seed',1);addParameter(p,'reuse_from',"");
addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));parse(p,varargin{:});o=p.Results;
ids=reshape(string(o.case_ids),1,[]);modes=reshape(string(o.modes),1,[]);
assert(~isempty(ids)&&all(ismember(ids,["M0","M2b","M4"]))&&numel(unique(ids))==numel(ids));
assert(~isempty(modes)&&all(ismember(modes,["ideal","lite"]))&&numel(unique(modes))==numel(modes));
assert(ismember(o.duration_s,[2,20]) && (o.duration_s==20 || all(ids~="M4")),'两秒烟雾仅M0/M2b，正式协议二十秒。');
assert(isscalar(o.seed)&&isfinite(o.seed)&&o.seed>=1&&o.seed==fix(o.seed));
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
out=fullfile(root,'results','e3_estimated_mismatch_'+string(o.output_tag));assert(~isfolder(out),'禁止覆盖研究结果。');mkdir(out);mkdir(fullfile(out,'logs'));mkdir(fullfile(out,'figures'));
reuse=string(o.reuse_from);if strlength(reuse)>0,assert(isfolder(reuse)&&startsWith(reuse,string(fullfile(root,'results'))+filesep),'仅重放本仓库已有结果。');end
[base,m,r,~,protocol,all_cases]=ca_mismatch_protocol(o.duration_s,0.6,"load_hold");cases=all_cases(ismember(string({all_cases.id}),ids));
writetable(ca_mismatch_cases(cases,m,protocol),fullfile(out,'cases.csv'),'Encoding','UTF-8');
windows=["whole","task","transient"];bounds=[0,o.duration_s;protocol.evaluation_window_s;0,min(6,o.duration_s)];
plan=table();for item=cases,for mode=modes,for method=base.methods
 plan=[plan;table(string(item.id),mode,method,"not_run","","",'VariableNames',{'case_id','estimator_mode','method','status','error_id','error_message'})];
end,end,end
S=table();provenance=table();index=0;stopped=false;
for item=cases
 for mode=modes
  c=base;c.estimator_mode=mode;c.navigation_mode="ideal";
  c.vane_gain_scale=item.gains;c.vane_deflection_map=string(item.mapping);c.vane_saturation_deg=item.saturation_deg;
  for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"],c.(field)=c.(field)+o.seed-1;end
  c.save_results=false;c.save_figures=false;c.show_figures=false;c=ca_validate_config(c);
  assert(isequaln(ca_allocator_config(c),ca_allocator_config(base)) && isequaln(ca_model(c),m),'ca:TruthLeak','失配进入分配器名义模型。');
  e=ca_prepare_experiment(c,r.time_s);
  save(fullfile(out,string(item.id)+'_'+mode+'_inputs.mat'),'c','r','e','protocol','-v7');
  for method=base.methods
   index=index+1;fprintf('E3 %s/%s/%s，%g秒\n',item.id,mode,method,c.duration_s);
   filename=string(item.id)+'_'+mode+'_'+method+'.mat';loaded=false;
   try
    if strlength(reuse)>0
     source=fullfile(reuse,'logs',filename);saved=load(source,'L','c','r','audit');
     assert(isequaln(saved.c,c)&&isequaln(saved.r,r),'E3重放配置或参考不一致。');L=saved.L;audit=saved.audit;loaded=true;
    else
     L=ca_simulate(m,c,r,method,e);L.time_for_metrics=r.time_s;
     assert(~any(L.table_extrapolated),'ca:AeroTableDomain','E3控制采样气动域越界。');audit="oracle_expected";
     if mode=="lite"
      assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'),'估计反馈出现真值topic。');audit="verified_absent";
     end
     L=rmfield(L,'topic_log');
    end
    save(fullfile(out,'logs',filename),'L','c','r','audit','-v7');
    for k=1:3
     row=estimator_feedback_metrics_row(L,m,string(item.id),mode,o.seed,windows(k),bounds(k,:));row.experiment_id="E3";row.smoke_test=o.duration_s==2;S=[S;row];
    end
    plan.status(index)="completed";provenance=[provenance;table(string(item.id),mode,method,o.seed,loaded,audit,'VariableNames',{'case_id','estimator_mode','method','seed','loaded','topic_check'})];
   catch problem
    plan.status(index)="failed";plan.error_id(index)=string(problem.identifier);plan.error_message(index)=string(problem.message);
    if index<height(plan),plan.status(index+1:end)="not_run_after_stop";end
    failure=struct('case_id',item.id,'estimator_mode',mode,'method',method,'identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
    fid=fopen(fullfile(out,'failure.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(failure,PrettyPrint=true));fclose(fid);save(fullfile(out,'failure.mat'),'failure','c','-v7');stopped=true;
   end
   writetable(plan,fullfile(out,'status.csv'),'Encoding','UTF-8');
   if ~isempty(S),writetable(S,fullfile(out,'summary.csv'),'Encoding','UTF-8');end
   if ~isempty(provenance),writetable(provenance,fullfile(out,'provenance.csv'),'Encoding','UTF-8');end
   if stopped,break;end
  end
  if stopped,break;end
 end
 if stopped,break;end
end
study=struct('output_dir',out,'summary',S,'status',plan,'provenance',provenance,'completed',all(plan.status=="completed"),'ECL_run',false,'protocol',protocol);
save(fullfile(out,'study.mat'),'study','-v7');
% 未完成时仍保留状态与已完成数据，不绘制或伪造缺失方法的完整对比。
if study.completed,study=e3_estimated_products(study,m);else
 fid=fopen(fullfile(out,'report.md'),'w','n','UTF-8');fprintf(fid,'# E3 按失败门禁停止\n\n完成 %d/%d；见 status.csv、failure.json。未改 record、未改模型或估计器，也没有真值兜底。\n',sum(plan.status=="completed"),height(plan));fclose(fid);
end
end
