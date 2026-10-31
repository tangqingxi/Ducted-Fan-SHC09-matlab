function study = allocation_comparison_products(study)
% 多种子池化、资格门禁和二维前沿分开计算；压力点永远不是排名候选。
S=study.summary;C=study.comparability;status=study.status;F=table();P=table();out=study.output_dir;
methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
metrics=["attitude_rmse_deg","yaw_rmse_deg","rate_rmse_deg_s","common_predicted_torque_error_rms_nm", ...
 "command_step_rms_deg","command_total_variation_deg","saturation_percent","position_rmse_m", ...
 "moment_model_error_rms_nm","allocation_demand_error_rms_rad_s2","common_residual_rms", ...
 "nominal_command_torque_error_rms_nm","mode1_percent","mode2_percent", ...
 "estimated_attitude_rmse_deg","estimated_position_rmse_m","bias_rmse_max_axis_deg_s"];
costs=["command_step_rms_deg","command_total_variation_deg","saturation_percent"];
objectives=["yaw_rmse_deg","rate_rmse_deg_s","common_predicted_torque_error_rms_nm"];
for g=1:height(C)
 id=C.case_id(g);mode=C.estimator_mode(g);load_value=C.load_fraction(g);category=C.comparability(g);
 wanted=status.case_id==id & status.estimator_mode==mode & status.load_fraction==load_value;
 expected=unique(status.seed(wanted));
 for window=["whole","task","transient"]
  T=table();if height(S)>0,T=S(S.case_id==id & S.estimator_mode==mode & S.load_fraction==load_value & S.window==window,:);end
  for metric=metrics
   means=NaN(1,5);deviations=means;counts=zeros(1,5);covered=false(1,5);
   for k=1:5
    if isempty(T),continue;end
    q=T.method==methods(k);v=T.(metric)(q);seed_values=T.seed(q);valid=isfinite(v);counts(k)=sum(valid);
    if any(valid),means(k)=mean(v(valid));end
    covered(k)=numel(v)==numel(expected)&&all(valid)&&isequal(sort(seed_values),sort(expected));
    if counts(k)>=2,deviations(k)=std(v(valid),0);end
   end
   spread=NaN;pooled=NaN;ratio=NaN;zero=false;
   if all(covered)
    spread=max(means)-min(means);
    if all(isfinite(deviations))
     pooled=sqrt(sum((counts-1).*deviations.^2)/sum(counts-1));zero=pooled==0;
     if pooled>0,ratio=spread/pooled;else,pooled=NaN;end
    end
   end
   distinction="not_distinguishable";
   if category=="rankable"&&isfinite(ratio)&&ratio>=1,distinction="distinguishable";end
   row=table(id,load_value,mode,window,metric,category,numel(expected),all(covered),spread,pooled,ratio,zero,distinction, ...
    'VariableNames',{'case_id','load_fraction','estimator_mode','window','metric','comparability','requested_seed_count','complete_seed_coverage','method_range','pooled_seed_std','range_over_seed_std','zero_pooled_variance','distinguishable'});
   for k=1:5
    row.('mean_'+methods(k))=means(k);row.('std_'+methods(k))=deviations(k);row.('n_'+methods(k))=counts(k);
   end
   F=[F;row];
  end
  for objective=objectives,for cost=costs
   x=NaN(5,1);y=x;coverage=false(5,1);
   for k=1:5
    if isempty(T),continue;end
    q=T.method==methods(k);a=T.(cost)(q);b=T.(objective)(q);
    coverage(k)=numel(a)==numel(expected)&&all(isfinite(a)&isfinite(b))&&isequal(sort(T.seed(q)),sort(expected));
    if coverage(k),x(k)=mean(a);y(k)=mean(b);end
   end
   [front,valid]=estimated_pareto_front(x,y);candidates=front & category=="rankable";role="candidate_frontier";
   if category=="stress",role="stress_not_ranking";elseif category=="invalid",role="invalid_not_ranking";end
   for k=1:5
    P=[P;table(id,load_value,mode,window,methods(k),cost,objective,x(k),y(k),valid(k),front(k),candidates(k),candidates(k),role,category, ...
    'VariableNames',{'case_id','load_fraction','estimator_mode','window','method','cost_metric','objective_metric','cost_value','objective_value','valid','numeric_non_dominated','pareto_candidate','pareto_efficient','ranking_status','comparability'})];
   end
  end,end
 end
end
writetable(F,fullfile(out,'effect_sizes.csv'),'Encoding','UTF-8');writetable(P,fullfile(out,'pareto.csv'),'Encoding','UTF-8');
fid=fopen(fullfile(out,'report.md'),'w','n','UTF-8');
fprintf(fid,'# 分配器比较：资格、种子波动与二维权衡\n\n|工况|负载|模式|资格|完成方法|种子|饱和最大%%|姿态峰值°|位置峰值m|估计姿态RMS°|原因|\n|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|\n');
for k=1:height(C)
 fprintf(fid,'|%s|%.1f|%s|%s|%d|%d|%.6g|%.6g|%.6g|%.6g|%s|\n',C.case_id(k),C.load_fraction(k),C.estimator_mode(k),C.comparability(k),C.completed_methods(k),C.requested_seed_count(k),C.max_saturation_percent(k),C.max_attitude_error_deg(k),C.max_position_error_m(k),C.attitude_estimate_rmse_deg(k),C.reason(k));
end
fprintf(fid,'\n完成%d/%d，失败%d，未运行%d。失败不补造指标；status/provenance记录全部计划。门禁按全部请求种子的主窗最坏值，不按方法均值。位置只报告不设门槛。rankable仅为比较资格；效应量比值≥1才标distinguishable，不是显著性或综合排名。\n\n',sum(status.status=="completed"),height(status),sum(status.status=="failed"),sum(status.status=="not_run"));
for g=1:height(C)
 id=C.case_id(g);mode=C.estimator_mode(g);load_value=C.load_fraction(g);category=C.comparability(g);
 fprintf(fid,'## %s / %s / %.0f%%：%s\n\n%s。\n\n',id,mode,load_value*100,category,C.reason(g));
 if category~="rankable",fprintf(fid,'压力或无效工况不排名，数值差异也不升级为候选前沿；退化量级见开头最坏值及以下方法均值。\n\n');end
 fprintf(fid,'|方法|主窗姿态°|偏航°|共同预测力矩Nm|PWM步变°|总变差°|饱和%%|位置m|\n|---|---:|---:|---:|---:|---:|---:|---:|\n');
 for method=methods
  fprintf(fid,'|%s',method);
  for metric=["attitude_rmse_deg","yaw_rmse_deg","common_predicted_torque_error_rms_nm","command_step_rms_deg","command_total_variation_deg","saturation_percent","position_rmse_m"]
   q=F.case_id==id & F.estimator_mode==mode & F.load_fraction==load_value & F.window=="task" & F.metric==metric;
   value=F.('mean_'+method)(q);fprintf(fid,'|%.6g',value);
  end
  fprintf(fid,'|\n');
 end
 if category=="rankable"
  fprintf(fid,'\n### 方法差异与种子波动\n\n|窗口|指标|方法均值极差|池化种子标准差|比值|可区分标记|\n|---|---|---:|---:|---:|---|\n');
  q=F.case_id==id & F.estimator_mode==mode & F.load_fraction==load_value;
  for k=find(q)',fprintf(fid,'|%s|%s|%.6g|%.6g|%.6g|%s|\n',F.window(k),F.metric(k),F.method_range(k),F.pooled_seed_std(k),F.range_over_seed_std(k),F.distinguishable(k));end
  fprintf(fid,'\n### 主窗二维候选前沿\n\n|代价轴|误差轴|数值候选方法|\n|---|---|---|\n');
  for objective=objectives,for cost=costs
   q=P.case_id==id & P.estimator_mode==mode & P.load_fraction==load_value & P.window=="task" & P.cost_metric==cost & P.objective_metric==objective & P.pareto_candidate;
   fprintf(fid,'|%s|%s|%s|\n',cost,objective,join(P.method(q),', '));
  end,end
  for method=["DCA","PCA_PREDICTIVE"]
   ratios=NaN(1,4);columns=["yaw_rmse_deg","common_predicted_torque_error_rms_nm","command_step_rms_deg","command_total_variation_deg"];
   for j=1:4
    q=F.case_id==id & F.estimator_mode==mode & F.load_fraction==load_value & F.window=="task" & F.metric==columns(j);
    numerator=F.('mean_'+method)(q);denominator=F.mean_PCA_STATIC(q);
    if isfinite(numerator)&&isfinite(denominator)&&denominator~=0,ratios(j)=numerator/denominator;end
   end
   q=F.case_id==id & F.estimator_mode==mode & F.load_fraction==load_value & F.window=="task" & F.metric=="saturation_percent";
   saturation_delta=F.('mean_'+method)(q)-F.mean_PCA_STATIC(q);
   fprintf(fid,'\n%s相对静态PCA的主窗均值比：偏航%.6g、共同力矩%.6g、PWM步变%.6g、总变差%.6g；饱和变化%.6g个百分点。分母零时比值NaN；这里只分别解释代价与误差，不合成排名。\n',method,ratios(1),ratios(2),ratios(3),ratios(4),saturation_delta);
  end
  fprintf(fid,'\n不同两轴的候选集合可能不同。共同力矩误差低但PWM步变/总变差高表示活动代价；饱和的方向另查，不能合成单一分数。候选前沿是几何非支配，不是统计显著性。\n\n');
 else
  fprintf(fid,'\nPareto各行统一标%s_not_ranking，pareto_candidate与pareto_efficient均false；numeric_non_dominated仅保留几何诊断。不得将压力点包装成算法排名。\n\n',category);
 end
end
fprintf(fid,'## 怎样读本结果\n\nwhole/task/transient=[0,20]/[6,16]/[0,6]；两秒烟雾三个窗口均[0,2]，不作正式结论。均值、方法内种子标准差和样本数逐方法保留；池化按(n−1)加权。任何方法缺失请求种子，跨五方法极差/池化比值保留NaN；单种子或零池化方差的比值NaN，不造无限大效应。\n\n');
fprintf(fid,'3种子只能描述本组效应与方向，无p值、显著性或全局最优。lite仍experimental且偏置门禁失败，平台默认ideal。tau匹配、无实机标定；原生残差不跨不同目标排名。allocation demand/common residual为rad/s²，共同预测力矩经名义J换算为Nm，不能替代实际力矩模型误差。真值仅测量生成与离线评价，没有反馈兜底。\n\n[汇总](summary.csv) · [可比性](comparability.csv) · [效应量](effect_sizes.csv) · [Pareto](pareto.csv) · [状态](status.csv) · [来源](provenance.csv)\n');
fclose(fid);study.effect_sizes=F;study.pareto=P;
end
