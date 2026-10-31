function study = e3_estimated_products(study,m)
% 复用MVP的二维权衡，按工况和反馈链分别统计，避免跨模式混合。
out=study.output_dir;S=study.summary;P=table();F=table();
for id=reshape(unique(S.case_id,'stable'),1,[])
 for mode=reshape(unique(S.estimator_mode,'stable'),1,[])
  T=S(S.case_id==id & S.estimator_mode==mode,:);folder=fullfile(out,id,mode);mkdir(folder);mkdir(fullfile(folder,'figures'));
  [p,f]=estimated_comparison_products(T,folder,"yaw_rmse_deg");
  copyfile(fullfile(folder,'figures','pareto_'+id+'_task.png'),fullfile(out,'figures','pareto_'+id+'_'+mode+'_task.png'));p.case_id=p.experiment;p.experiment_id=repmat("E3",height(p),1);f.case_id=f.experiment;f.experiment_id=repmat("E3",height(f),1);f.estimator_mode=repmat(mode,height(f),1);P=[P;p];F=[F;f];
 end
end
writetable(P,fullfile(out,'pareto.csv'),'Encoding','UTF-8');writetable(F,fullfile(out,'metric_effects.csv'),'Encoding','UTF-8');
for id=["M4","M2b"]
 if ~any(S.case_id==id),continue;end
 modes=unique(S.estimator_mode,'stable');fig=figure('Visible','off','Position',[50,50,1650,750]);clean=onCleanup(@()close(fig));tiles=tiledlayout(fig,numel(modes),3,'TileSpacing','compact');
 for mode=reshape(modes,1,[])
  ax=nexttile(tiles);hold(ax,'on');cx=nexttile(tiles);hold(cx,'on');bx=nexttile(tiles);hold(bx,'on');
  for method=reshape(unique(S.method,'stable'),1,[])
   saved=load(fullfile(out,'logs',id+'_'+mode+'_'+method+'.mat'),'L');L=saved.L;t=L.time_for_metrics;
   torque=L.common_predicted_delta_rad*m.torque_matrix'-(L.v_h+L.v_c)*m.parameters.J';
   plot(ax,t,rad2deg(L.euler_error_rad(:,3)),'DisplayName',method);plot(cx,t,rad2deg(L.rotation_error_rad),'DisplayName',method);plot(bx,t,vecnorm(torque,2,2),'DisplayName',method);
  end
  xlabel(ax,'time_s');ylabel(ax,'yaw_error_deg');title(ax,id+" / "+mode,'Interpreter','none');grid(ax,'on');legend(ax,'Interpreter','none','Location','best','AutoUpdate','off');
  xlabel(cx,'time_s');ylabel(cx,'attitude_error_deg');grid(cx,'on');
  xlabel(bx,'time_s');ylabel(bx,'common_predicted_torque_error_nm');grid(bx,'on');
  xline(ax,2,':','load');xline(ax,16,':','unload');xline(cx,2,':');xline(cx,16,':');xline(bx,2,':');xline(bx,16,':');
 end
 title(tiles,id+" : time response / nominal common prediction",'Interpreter','none');exportgraphics(fig,fullfile(out,'figures',id+'_time.png'),'Resolution',120);clear clean;
end
fid=fopen(fullfile(out,'report.md'),'w','n','UTF-8');
fprintf(fid,'# E3 估计反馈结构失配\n\n完成 %d 个工况/模式/方法组合；同组只更换分配器。单组配对种子，仅方向和效应量，不作显著性或实机主张。lite experimental；默认 ideal；tau 匹配；未运行可选 ECL（墙钟代价高，不是发布门槛）。\n\n',height(study.status));
fprintf(fid,'二十秒协议，2秒加载、16秒卸载、0.5秒过渡；whole=[0,20]、task=[6,16]、transient=[0,6]。两秒烟雾三个窗口均为[0,2]，不是正式研究结果。\n\n');
fprintf(fid,'## 分窗结果\n\n|工况|模式|方法|窗口|偏航度|角速度度每秒|共同预测力矩Nm|PWM步变度|饱和%%|mode1/2%%|姿态估计度|\n|---|---|---|---|---:|---:|---:|---:|---:|---|---:|\n');
for k=1:height(S)
 fprintf(fid,'|%s|%s|%s|%s|%.6g|%.6g|%.6g|%.6g|%.6g|%.6g/%.6g|%.6g|\n',S.case_id(k),S.estimator_mode(k),S.method(k),S.window(k),S.yaw_rmse_deg(k),S.rate_rmse_deg_s(k),S.common_predicted_torque_error_rms_nm(k),S.command_step_rms_deg(k),S.saturation_percent(k),S.mode1_percent(k),S.mode2_percent(k),S.estimated_attitude_rmse_deg(k));
end
fprintf(fid,'\n## 对问题的回答依据\n\n');
for id=["M4","M2b"]
 if ~any(S.case_id==id),continue;end
 for mode=reshape(unique(S.estimator_mode,'stable'),1,[])
  a=S(S.case_id==id & S.estimator_mode==mode & S.window=="task",:);b=S(S.case_id==id & S.estimator_mode==mode & S.window=="transient",:);
  stat=a.yaw_rmse_deg(a.method=="PCA_STATIC");dca=a.yaw_rmse_deg(a.method=="DCA");pred=a.yaw_rmse_deg(a.method=="PCA_PREDICTIVE");
  fprintf(fid,'- %s/%s：主窗静态/DCA=%.6g，静态/预测=%.6g；早期静态/DCA=%.6g。主窗姿态估计误差均值%.6g度。\n',id,mode,stat/dca,stat/pred,b.yaw_rmse_deg(b.method=="PCA_STATIC")/b.yaw_rmse_deg(b.method=="DCA"),mean(a.estimated_attitude_rmse_deg));
  if mode=="lite"
   fprintf(fid,'  沿用MVP规则：单种子波动未知，不能据姿态/偏航主窗数值作统计排名。是否被估计误差掩盖，结合ideal/lite跨度、早期窗及分配指标解释，不另造分辨门限。\n');
  end
 end
end
fprintf(fid,'\nM4 是否保留收敛差异，由早期/主窗及 M4_time 图共同判断；不从主窗单一误差推导稳定性。M2b 的行空间效应需与同模式 M0 对照，summary 同时保留真实力矩模型失配 moment_model_error_rms_nm 与名义共同残差。PWM/饱和与共同力矩残差构成 Pareto 权衡，不宣布单一最优。\n\n');
fprintf(fid,'common_residual 和 allocation demand error 为 rad/s²，乘名义J后才为Nm；native residual 不跨原生动态目标排名。黑圈仅为该指标对的数值非支配点，没有综合分数；单种子未知波动，不能统计排名。实际力矩模型误差与名义预测力矩误差含义不同，匹配tau有利于预测模型。\n\n[汇总](summary.csv) · [Pareto](pareto.csv) · [效应量](metric_effects.csv) · [状态](status.csv)\n');
for id=reshape(unique(S.case_id,'stable'),1,[])
 for mode=reshape(unique(S.estimator_mode,'stable'),1,[])
  fprintf(fid,'\n![%s/%s 主窗](%s/%s/figures/pareto_%s_task.png)\n',id,mode,id,mode,id);
 end
 if ismember(id,["M4","M2b"]),fprintf(fid,'\n![%s 时域](figures/%s_time.png)\n',id,id);end
end
fclose(fid);study.pareto=P;study.metric_effects=F;
end
