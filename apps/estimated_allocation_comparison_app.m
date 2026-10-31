function study = estimated_allocation_comparison_app(varargin)
% 缓存优先的五方法比较；只改变分配器，不改变平台默认或门禁。
root=ca_setup();p=inputParser;
addParameter(p,'mode',"lite");addParameter(p,'experiments',"both");addParameter(p,'seeds',1);
addParameter(p,'use_cached',true);addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
addParameter(p,'smoke_test',false);parse(p,varargin{:});o=p.Results;
mode=string(o.mode);experiments=reshape(string(o.experiments),1,[]);seeds=reshape(o.seeds,1,[]);
assert(isscalar(mode)&&ismember(mode,["ideal","lite","px4_ecl"]),'未知反馈模式。');
if isequal(experiments,"both"),experiments=["E1","E2"];end
assert(~isempty(experiments)&&all(ismember(experiments,["E1","E2"]))&&numel(unique(experiments))==numel(experiments));
assert(~isempty(seeds)&&all(isfinite(seeds)&seeds>=1&seeds==fix(seeds))&&numel(unique(seeds))==numel(seeds));
assert(isscalar(o.use_cached)&&ismember(o.use_cached,[true,false])&&isscalar(o.smoke_test)&&ismember(o.smoke_test,[true,false]));
assert(~o.smoke_test || isequal(experiments,"E1"),'烟雾测试仅用于两秒E1。');
if mode=="px4_ecl",assert(usejava('jvm'),'ECL需要JVM。');end
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')),'结果标签格式错误。');
out=fullfile(root,'results','estimated_comparison_'+string(o.output_tag));assert(~isfolder(out),'禁止覆盖已有比较。');mkdir(out);mkdir(fullfile(out,'figures'));
cache_dir=fullfile(root,'results','estimated_comparison_cache');if ~isfolder(cache_dir),mkdir(cache_dir);end
S=table();provenance=table();
role="experimental";if mode=="ideal",role="oracle";elseif mode=="px4_ecl",role="independent_cross_validation";end
for experiment=experiments
 for seed=seeds
  if experiment=="E1"
   c=ca_config();c.duration_s=12;c.roll_amplitude_deg=2;c.pitch_amplitude_deg=2;c.yaw_amplitude_deg=5;
   c.aero_low_speed_model="hold_90";c.aero_extrapolation_policy="error";
  else
   [c,~,~,~]=ca_mismatch_protocol(20,0.6,"load_hold");
  end
  if o.smoke_test,c.duration_s=2;end
  c.estimator_mode=mode;c.navigation_mode="ideal";
  for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"],c.(field)=c.(field)+seed-1;end
  c.show_figures=false;c.save_figures=false;c.save_results=false;c=ca_validate_config(c);
  m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);
  [windows,bounds]=estimated_comparison_windows(experiment,o.smoke_test);
  for method=c.methods
   cache=fullfile(cache_dir,experiment+'_'+mode+'_seed'+seed+'_smoke'+double(o.smoke_test)+'_'+method+'.mat');
   candidates=string.empty;
   if o.use_cached
    if seed==1 && ~o.smoke_test
     if mode=="px4_ecl",candidates=fullfile(root,'results','estimator_diagnosis','ECL',experiment+'_'+method+'.mat');
     else,candidates=fullfile(root,'results','estimator_diagnosis','metrics',experiment+'_'+mode+'_'+method+'.mat');end
    end
    candidates=[candidates,string(cache)];
   end
   loaded=false;origin="";topic_check="";
   for candidate=candidates
    if ~isfile(candidate),continue;end
    saved=load(candidate,'L','c','r');
    variables=whos('-file',candidate);if any(string({variables.name})=="topic_audit"),audit=load(candidate,'topic_audit');saved.topic_audit=audit.topic_audit;end
    assert(isequaln(saved.c,c)&&isequaln(saved.r,r),'shc09:ComparisonCacheMismatch','缓存配置/参考不匹配，停止而非静默使用。');
    L=saved.L;loaded=true;origin=candidate;topic_check="unavailable_numeric_cache";
    if isfield(saved,'topic_audit'),topic_check=saved.topic_audit;end
    break;
   end
   if ~loaded
    fprintf('最小补跑 %s/%s/seed%d/%s\n',experiment,mode,seed,method);
    try
     L=ca_simulate(m,c,r,method,e);L.time_for_metrics=r.time_s;
     topic_check="oracle_expected";
     if mode~="ideal"
      assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'),'估计反馈出现真值topic。');
      topic_check="verified_absent";
     end
     L=rmfield(L,'topic_log');topic_audit=topic_check;save(cache,'L','c','r','topic_audit','-v7');origin=string(cache);
    catch problem
     failure=struct('experiment',experiment,'seed',seed,'method',method,'identifier',problem.identifier,'message',problem.message);
     fid=fopen(fullfile(out,'failure.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(failure,PrettyPrint=true));fclose(fid);rethrow(problem);
    end
   end
   for k=1:numel(windows)
    row=estimator_feedback_metrics_row(L,m,experiment,mode,seed,windows(k),bounds(k,:));row.backend_role=role;row.smoke_test=logical(o.smoke_test);S=[S;row];
   end
   provenance=[provenance;table(experiment,mode,seed,method,origin,loaded,topic_check)];
   writetable(S,fullfile(out,'summary.csv'),'Encoding','UTF-8');writetable(provenance,fullfile(out,'provenance.csv'),'Encoding','UTF-8');
  end
 end
end
[P,F]=estimated_comparison_products(S,out);writetable(P,fullfile(out,'pareto.csv'),'Encoding','UTF-8');writetable(F,fullfile(out,'metric_effects.csv'),'Encoding','UTF-8');
fid=fopen(fullfile(out,'report.md'),'w','n','UTF-8');
fprintf(fid,'# 估计反馈分配比较\n\n模式：%s（%s），种子：%s。五方法共享参考、初态、随机流，仅更换分配器。\n\n',mode,role,join(string(seeds),','));
fprintf(fid,'lite 未验收，ideal 仅 oracle，ECL 为归档旧版独立交叉验证；默认仍 ideal，tau 仍匹配。单种子/三种子不作显著性或全局最优主张。\n\n');
fprintf(fid,'二维 Pareto 均最小化横轴代价与纵轴误差，黑圈为该指标对的非支配点；1–5 对应 DA_NS/WLS/DCA/PCA_STATIC/PCA_PREDICTIVE。没有综合得分，native residual 不跨动态目标排名。\n\n');
fprintf(fid,'E1 whole/task/transient=[0,12]/[2,10]/[0,2]；E2=[0,20]/[6,16]/[0,6]。E2 whole 看早期响应，task 看稳态误差；烟雾输出使用单独两秒窗口，不能替代正式协议。\n\n');
fprintf(fid,'历史数值缓存已剥离 topic，provenance 中 unavailable_numeric_cache 表示不能直接重查 topic；新仿真记录 verified_absent。真值只用于仿真测量生成与离线评价，无真值兜底。\n\n');
q=ismember(F.metric,["attitude_rmse_deg","yaw_rmse_deg"]);
for k=find(q)',fprintf(fid,'- %s/%s/%s：%s（波动来源 %s）。\n',F.experiment(k),F.window(k),F.metric(k),F.resolution(k),F.noise_source(k));end
fprintf(fid,'\n[汇总](summary.csv) · [Pareto](pareto.csv) · [效应量](metric_effects.csv)\n');
for experiment=experiments
 for window=["whole","task","transient"],fprintf(fid,'\n![%s/%s](figures/pareto_%s_%s.png)\n',experiment,window,experiment,window);end
end
fclose(fid);study=struct('output_dir',out,'summary',S,'pareto',P,'metric_effects',F,'provenance',provenance);
end
