function metrics = estimator_feedback_metrics()
% 原始Stage5目录没有逐时刻日志时，仅补单种子配对设计，不重跑四十次。
root=ca_setup();source=fullfile(root,'results','estimator_realism_20261031_093105_400');
assert(isfolder(source),'缺少指定Stage5来源。');out=fullfile(root,'docs','estimator_diagnosis');
raw=fullfile(root,'results','estimator_diagnosis','metrics');if ~isfolder(raw),mkdir(raw);end
metrics=table();provenance=table();
for experiment=["E1","E2"]
 for mode=["ideal","lite"]
  if experiment=="E1"
   c=ca_config();c.duration_s=12;c.roll_amplitude_deg=2;c.pitch_amplitude_deg=2;c.yaw_amplitude_deg=5;
   c.aero_low_speed_model="hold_90";c.aero_extrapolation_policy="error";offset=0;
  else
   [c,~,~,~]=ca_mismatch_protocol(20,0.6,"load_hold");offset=30;
  end
  c.estimator_mode=mode;c.navigation_mode="ideal";c.show_figures=false;c.save_figures=false;c.save_results=false;
  c=ca_validate_config(c);m=ca_model(c);r=ca_reference(c);e=ca_prepare_experiment(c,r.time_s);
  for k=1:numel(c.methods)
   method=c.methods(k);filename=fullfile(raw,experiment+'_'+mode+'_'+method+'.mat');
   % 优先寻找原目录日志；旧入口实际只保存配置和汇总。
   legacy=fullfile(source,sprintf('log_%02d.mat',offset+5*(mode=="lite")+k));
   if isfile(legacy)
    d=load(legacy);L=d.L;origin=string(legacy);rerun=false;
   elseif isfile(filename)
    d=load(filename);assert(isequaln(d.c,c) && isequaln(d.r,r),'缓存配置或参考不一致。');L=d.L;origin=string(filename);rerun=false;
   else
    fprintf('补充日志 %s/%s/%s\n',experiment,mode,method);
    L=ca_simulate(m,c,r,method,e);L.time_for_metrics=r.time_s;
    L=rmfield(L,'topic_log');save(filename,'L','c','r','-v7');origin=string(filename);rerun=true;
   end
   provenance=[provenance;table(experiment,mode,method,origin,rerun)];
   for window=["whole","task","transient"]
    bounds=[0,c.duration_s];
    if experiment=="E1"
     if window=="task",bounds=[2,10];elseif window=="transient",bounds=[0,2];end
    else
     if window=="task",bounds=[6,16];elseif window=="transient",bounds=[0,6];end
    end
    row=estimator_feedback_metrics_row(L,m,experiment,mode,1,window,bounds);metrics=[metrics;row];
   end
   writetable(metrics,fullfile(out,'metrics.csv'),'Encoding','UTF-8');
   writetable(provenance,fullfile(out,'metrics_provenance.csv'),'Encoding','UTF-8');
  end
 end
end
% 比值的分母与分子同量纲：估计链引起的同指标配对位移，非显著性检验。
columns=["attitude_rmse_deg","yaw_rmse_deg","position_rmse_m","rate_rmse_deg_s", ...
 "allocation_demand_error_rms_rad_s2","nominal_command_torque_error_rms_nm","common_predicted_torque_error_rms_nm","common_residual_rms","native_residual_rms", ...
 "command_step_rms_deg","command_total_variation_deg","saturation_percent","mode1_percent","mode2_percent", ...
 "prediction_rmse_deg","moment_model_error_rms_nm","estimated_attitude_rmse_deg","estimated_position_rmse_m","bias_rmse_max_axis_deg_s","bias_final_max_axis_deg_s"];
effects=table();
for experiment=["E1","E2"]
 for window=["whole","task","transient"]
  I=metrics(metrics.case_id==experiment & metrics.window==window & metrics.estimator_mode=="ideal",:);
  F=metrics(metrics.case_id==experiment & metrics.window==window & metrics.estimator_mode=="lite",:);
  assert(isequal(I.method,F.method),'配对方法顺序不一致。');
  for metric=columns
   x=I.(metric);y=F.(metric);span=max(y)-min(y);shift=sqrt(mean((y-x).^2,'omitnan'));
   ratio=span/shift;if shift==0,ratio=NaN;end
   s=y(F.method=="PCA_STATIC");d=y(F.method=="DCA");p=y(F.method=="PCA_PREDICTIVE");
   effects=[effects;table(experiment,window,metric,span,shift,ratio,s,d,p, ...
    'VariableNames',{'experiment','window','metric','lite_method_range','paired_estimator_chain_shift_rms','range_over_chain_shift','static_value','dca_value','predictive_value'})];
  end
 end
end
writetable(effects,fullfile(out,'metric_effects.csv'),'Encoding','UTF-8');
% 用原三种子汇总估计同指标的种子波动；单种子或无历史字段时不能估计。
old=readtable(fullfile(source,'summary.csv'),'TextType','string');seed_effects=table();
for metric=columns
 span=NaN;pooled=NaN;ratio=NaN;count=0;
 if ismember(metric,string(old.Properties.VariableNames))
  means=[];variances=[];
  for method=c.methods
   values=old.(metric)(old.case_id=="E1" & old.estimator_mode=="lite" & old.method==method & old.window=="whole");
   count=numel(values);means(end+1)=mean(values,'omitnan');variances(end+1)=var(values,'omitnan');
  end
  span=max(means)-min(means);pooled=sqrt(mean(variances,'omitnan'));if pooled>0,ratio=span/pooled;end
 end
 seed_effects=[seed_effects;table(metric,count,span,pooled,ratio, ...
  'VariableNames',{'metric','E1_seed_count','method_mean_range','pooled_within_method_seed_std','range_over_seed_std'})];
end
writetable(seed_effects,fullfile(out,'metric_seed_effects.csv'),'Encoding','UTF-8');
fid=fopen(fullfile(out,'metrics.json'),'w','n','UTF-8');fwrite(fid,jsonencode(table2struct(metrics),PrettyPrint=true),'char');fclose(fid);
end
