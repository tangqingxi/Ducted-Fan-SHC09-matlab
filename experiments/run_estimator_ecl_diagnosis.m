function summary = run_estimator_ecl_diagnosis(experiments,methods)
% 官方归档ECL固定单种子十次交叉验证；失败停止本组，不回退。
if nargin<1,experiments=["E1","E2"];end
experiments=reshape(string(experiments),1,[]);assert(all(ismember(experiments,["E1","E2"])) && numel(unique(experiments))==numel(experiments));suffix="";if numel(experiments)==1,suffix="_"+experiments;end
if nargin>=2,methods=reshape(string(methods),1,[]);suffix=suffix+"_"+join(methods,"_");end
root=ca_setup();assert(usejava('jvm'),'ECL需要JVM。');out=fullfile(root,'docs','estimator_diagnosis');
raw=fullfile(root,'results','estimator_diagnosis','ECL');if ~isfolder(raw),mkdir(raw);end
summary=table();status=table();
for experiment=experiments
 if experiment=="E1"
  c=ca_config();c.duration_s=12;c.roll_amplitude_deg=2;c.pitch_amplitude_deg=2;c.yaw_amplitude_deg=5;
  c.aero_low_speed_model="hold_90";c.aero_extrapolation_policy="error";
 else
  [c,~,~,~]=ca_mismatch_protocol(20,0.6,"load_hold");
 end
 c.estimator_mode="px4_ecl";c.navigation_warmup_s=15;c.show_figures=false;c.save_figures=false;c.save_results=false;
 c=ca_validate_config(c);m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);failed=false;
 selected=c.methods;if nargin>=2,assert(all(ismember(methods,c.methods)) && numel(unique(methods))==numel(methods));selected=methods;end
 for method=selected
  state="completed";message="";fprintf('ECL %s/%s\n',experiment,method);
  cache=fullfile(raw,experiment+'_'+method+'.mat');
  failure_file=fullfile(raw,experiment+'_failure.mat');
  if isfile(failure_file),failed=true;end
  if failed && ~isfile(cache)
   state="skipped_after_group_failure";
   prior=load(failure_file,'failure');
   if isfield(prior.failure,'method') && string(prior.failure.method)==method
    state="failed";message=string(prior.failure.identifier)+": "+string(prior.failure.message);
   end
  else
   try
    cache=fullfile(raw,experiment+'_'+method+'.mat');
    if isfile(cache)
     saved=load(cache,'L','c','r');assert(isequaln(saved.c,c) && isequaln(saved.r,r),'ECL缓存配置或参考不一致。');L=saved.L;
    else
     L=ca_simulate(m,c,r,method,e);L.time_for_metrics=r.time_s;
     L=rmfield(L,'topic_log');save(cache,'L','c','r','-v7');
    end
    windows="whole";if experiment=="E2",windows=["whole","task","transient"];end
    for window=windows
     bounds=[0,c.duration_s];if window=="task",bounds=[6,16];elseif window=="transient",bounds=[0,6];end
     row=estimator_feedback_metrics_row(L,m,experiment,"px4_ecl",1,window,bounds);
     row.warmup_elapsed_s=L.navigation_warmup_elapsed_s;row.simulation_elapsed_s=L.elapsed_s;
     summary=[summary;row];
    end
   catch problem
    failed=true;state="failed";message=string(problem.identifier)+": "+string(problem.message);
    failure=struct('experiment',experiment,'method',method,'identifier',problem.identifier,'message',problem.message,'stack',problem.stack);
    save(fullfile(raw,experiment+'_failure.mat'),'failure','c');
   end
  end
  status=[status;table(experiment,method,state,message)];
  writetable(status,fullfile(out,'ecl_status'+suffix+'.csv'),'Encoding','UTF-8');
  if ~isempty(summary),writetable(summary,fullfile(out,'ecl'+suffix+'.csv'),'Encoding','UTF-8');end
 end
end
fid=fopen(fullfile(out,'ecl'+suffix+'.json'),'w','n','UTF-8');fwrite(fid,jsonencode(table2struct(summary),PrettyPrint=true),'char');fclose(fid);
end
