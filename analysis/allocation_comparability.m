function C = allocation_comparability(S,status)
% 门禁先于扫描固定：五方法完整、主窗饱和不超过10%、姿态峰值不超过5度、无表外、lite估计RMS不超过2度。
C=table();groups=unique(status(:,{'case_id','load_fraction','estimator_mode'}),'rows','stable');
required=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
for g=1:height(groups)
 id=groups.case_id(g);load_value=groups.load_fraction(g);mode=groups.estimator_mode(g);
 q=status.case_id==id & status.load_fraction==load_value & status.estimator_mode==mode;T=status(q,:);
 task=table();if height(S)>0,task=S(S.case_id==id & S.load_fraction==load_value & S.estimator_mode==mode & S.window=="task",:);end
 completed=0;requested_seeds=unique(T.seed);
 for method=required
  a=T(T.method==method,:);
  if ~isempty(a)&&all(a.status=="completed")&&isequal(sort(a.seed),sort(requested_seeds)),completed=completed+1;end
 end
 sat=NaN;att=NaN;position=NaN;estimate=NaN;aero=NaN;
 if ~isempty(task)
  sat=max(task.saturation_percent);att=max(task.attitude_peak_deg);position=max(task.position_peak_m);
  estimate=max(task.estimated_attitude_rmse_deg);aero=max(task.aero_extrapolated_count);
 end
 failed=sum(T.status=="failed");not_run=sum(T.status=="not_run");reasons=string.empty;category="rankable";
 if completed<5||any(T.status~="completed"),reasons(end+1)="五方法及全部请求种子未完成";end
 if sat>10,reasons(end+1)="主窗饱和超过10%";end
 if att>5,reasons(end+1)="主窗姿态峰值超过5度";end
 if mode=="lite"&&estimate>2,reasons(end+1)="lite姿态估计RMS超过2度";end
 if any(T.smoke_test),reasons(end+1)="两秒烟雾不是正式比较";end
 if any(reasons~=""),category="stress";end
 invalid_aero=any(T.aero_extrapolated)|aero>0;
 if invalid_aero,category="invalid";reasons(end+1)="气动表域失败或越界";aero=max([0,aero],[],'omitnan')+double(aero==0||isnan(aero));end
 if ~isempty(task)&&any(~isfinite([task.saturation_percent,task.attitude_peak_deg,task.position_peak_m,task.estimated_attitude_rmse_deg,task.aero_extrapolated_count]),'all')
  category="invalid";reasons(end+1)="门禁评价包含非有限数";
 end
 if any(contains(T.error_id,["CacheMismatch","TopicAudit"]))
  category="invalid";reasons(end+1)="缓存或真值隔离审计失败";
 end
 if isempty(reasons),reasons="全部预定义门禁通过；不是统计排名";end
 seeds=numel(unique(T.seed));
 C=[C;table(id,load_value,mode,completed,seeds,failed,not_run,sat,att,position,estimate,aero,category,join(reasons,'；'), ...
 'VariableNames',{'case_id','load_fraction','estimator_mode','completed_methods','requested_seed_count','failed_runs','not_run_runs', ...
 'max_saturation_percent','max_attitude_error_deg','max_position_error_m','attitude_estimate_rmse_deg','aero_extrapolated','comparability','reason'})];
end
end
