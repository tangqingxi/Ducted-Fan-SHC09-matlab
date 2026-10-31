function [pareto,effects] = estimated_comparison_products(S,out,primary_metric)
% 逐实验、逐窗口展示二维权衡；不跨目标计算综合分数。
pareto=table();effects=table();costs=["command_step_rms_deg","command_total_variation_deg","saturation_percent"];
metrics=["attitude_rmse_deg","yaw_rmse_deg","position_rmse_m","rate_rmse_deg_s", ...
 "common_residual_rms","common_predicted_torque_error_rms_nm","allocation_demand_error_rms_rad_s2", ...
 "nominal_command_torque_error_rms_nm","native_residual_rms",costs,"mode1_percent","mode2_percent", ...
 "estimated_attitude_rmse_deg","estimated_position_rmse_m","bias_rmse_max_axis_deg_s"];
root=ca_setup();old=readtable(fullfile(root,'examples','estimator_realism','summary.csv'),'TextType','string');
for experiment=reshape(unique(S.case_id,'stable'),1,[])
 for window=["whole","task","transient"]
  T=S(S.case_id==experiment & S.window==window,:);methods=unique(T.method,'stable');mode=T.estimator_mode(1);
  for metric=metrics
   means=zeros(numel(methods),1);variances=NaN(size(means));counts=zeros(size(means));source="current_seeds";
   for k=1:numel(methods)
    v=T.(metric)(T.method==methods(k));means(k)=mean(v,'omitnan');counts(k)=numel(v);
    if numel(v)>1,variances(k)=var(v,'omitnan');end
   end
   spread=max(means)-min(means);noise=sqrt(mean(variances,'omitnan'));n=min(counts);
   if n==1 && experiment=="E1" && window=="whole" && mode=="lite" && T.window_end_s(1)==12 && ismember(metric,string(old.Properties.VariableNames))
    for k=1:numel(methods)
     v=old.(metric)(old.case_id==experiment & old.window==window & old.estimator_mode==mode & old.method==methods(k));variances(k)=var(v,'omitnan');
    end
    noise=sqrt(mean(variances,'omitnan'));source="historical_E1_three_seeds";
   elseif n==1,source="unavailable_single_seed";end
   ratio=NaN;if noise>0,ratio=spread/noise;end
   resolution="效应量，非显著性";
   if ismember(metric,["attitude_rmse_deg","yaw_rmse_deg"])
    resolution="种子波动未知，不能排名";
    if isfinite(noise) && noise>0
     resolution="差异大于种子波动，仍不构成显著性";if spread<noise,resolution="不可分辨";end
    end
   end
   effects=[effects;table(experiment,window,metric,n,spread,noise,ratio,source,resolution, ...
    'VariableNames',{'experiment','window','metric','current_seed_count','method_range','pooled_seed_std','range_over_seed_std','noise_source','resolution'})];
  end
  target="attitude_rmse_deg";if experiment=="E2",target="yaw_rmse_deg";end
  if nargin>=3,target=string(primary_metric);end
  objectives=[target,"rate_rmse_deg_s","common_predicted_torque_error_rms_nm"];
  f=figure('Visible','off','Position',[50,50,1450,1100]);clean=onCleanup(@()close(f));
  tiles=tiledlayout(f,3,3,'TileSpacing','compact','Padding','compact');
  target="attitude_rmse_deg";if experiment=="E2",target="yaw_rmse_deg";end
  if nargin>=3,target=string(primary_metric);end
  note=effects.resolution(effects.experiment==experiment & effects.window==window & effects.metric==target);
  title(tiles,[experiment+" / "+window+" / "+mode+" : Pareto (no composite score)";target+" : "+note], ...
   'Interpreter','none','FontName','Microsoft YaHei');
  colors=lines(numel(methods));markers={'o','s','^','d','v'};
  for yi=1:3
   for xi=1:3
    x=zeros(numel(methods),1);y=x;
    for k=1:numel(methods)
     q=T.method==methods(k);x(k)=mean(T.(costs(xi))(q),'omitnan');y(k)=mean(T.(objectives(yi))(q),'omitnan');
    end
    [front,valid]=estimated_pareto_front(x,y);
    ax=nexttile(tiles);hold(ax,'on');
    for k=1:numel(methods)
     pareto=[pareto;table(experiment,window,mode,methods(k),costs(xi),objectives(yi),x(k),y(k),valid(k),front(k), ...
      'VariableNames',{'experiment','window','estimator_mode','method','cost_metric','objective_metric','cost_value','objective_value','valid','pareto_efficient'})];
     scatter(ax,x(k),y(k),75,colors(k,:),markers{k},'filled','DisplayName',methods(k));
     if valid(k) && k>=3,text(ax,x(k),y(k)," "+string(k),'FontSize',9,'VerticalAlignment','bottom');end
    end
    if any(front),scatter(ax,x(front),y(front),145,'k','o','LineWidth',1,'HandleVisibility','off');end
    xlabel(ax,costs(xi),'Interpreter','none');ylabel(ax,objectives(yi),'Interpreter','none');grid(ax,'on');
    if yi==1 && xi==1,legend(ax,'Location','best','Interpreter','none');end
   end
  end
  exportgraphics(f,fullfile(out,'figures','pareto_'+experiment+'_'+window+'.png'),'Resolution',120);
  clear clean;
 end
end
end
