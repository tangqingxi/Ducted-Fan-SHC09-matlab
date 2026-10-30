function ca_mismatch_report(study)
% 按实际协议报告成功、失败和未运行项，完整轮次的综合解释另存总报告。
file=fopen(fullfile(study.output_dir,'report.md'),'w','n','UTF-8');
assert(file>=0,'报告文件不可写。'); cleanup=onCleanup(@()fclose(file)); %#ok<NASGU>
count=sum(string(study.status.status)=="completed"); failed=sum(string(study.status.status)=="failed");
planned=numel(study.options.case_ids)*numel(study.config.methods);
fprintf(file,'# SHC09 对象侧结构失配第二轮\n\n完成%d/%d，失败%d，未运行%d。完整运行标志%d，整体停止%d。\n\n', ...
    count,planned,failed,planned-count-failed,study.completed,study.stopped);
fprintf(file,'协议%s，时长%g秒，负载%.0f%%，评价窗[%g,%g]秒；WLS轴权重[%g,%g,%g]。\n\n', ...
    study.protocol.mode,study.config.duration_s,100*study.protocol.load_fraction,study.protocol.evaluation_window_s,study.config.wls_axis_weights);
fprintf(file,'低速模型%s，阈值%gm/s；hold_90在阈值内取90°，阈值至两倍阈值混合气动力和力矩，阈值外仍检查原始迎角，绝不跳过门禁。\n\n', ...
    study.config.aero_low_speed_model,study.config.aero_low_speed_m_s);
fprintf(file,'导航ideal，真实及模型tau均30ms、不缓变。所有方法同一初态/参考/噪声/外扰，仅对象舵效不同；控制器、分配器算法、名义B及白名单不变。\n\n');
fprintf(file,'种子gyro=%u，attitude=%u，disturbance=%u。单组配对种子，不主张统计显著性或实机优势。\n\n', ...
    study.protocol.gyro_noise_seed,study.protocol.attitude_noise_seed,study.protocol.disturbance_seed);
plan=table();
for id=reshape(string(study.options.case_ids),1,[])
 for method=study.config.methods
    match=string(study.status.case_id)==id & string(study.status.method)==method; state="not_run_after_stop";
    if any(match), state=string(study.status.status(find(match,1))); end
    plan=[plan;table(id,method,state,'VariableNames',{'case_id','method','status'})]; %#ok<AGROW>
 end
end
writetable(plan,fullfile(study.output_dir,'plan_status.csv'),'Encoding','UTF-8');
defs=readtable(fullfile(study.output_dir,'cases.csv'),'TextType','string');
fprintf(file,'| 工况 | 映射 | 行空间失配 | 零空间失配 |\n|---|---|---:|---:|\n');
for k=1:height(defs), fprintf(file,'| %s | %s | %.8g | %.8g |\n',defs.case_id(k),defs.map(k),defs.rowspace_mismatch(k),defs.nullspace_mismatch(k)); end
fprintf(file,'\nM4为名义负载工作点局部导数，工作点六舵角记录在cases.csv；不是全局常矩阵。\n\n');
if ~isempty(study.summary)
 task=study.summary(study.summary.window=="task",:); relative=table();
 fprintf(file,'| 工况 | 方法 | 偏航RMSE ° | 姿态RMSE ° | 力矩误差RMS Nm | 饱和 %% | 步变RMS ° | 正则化 %% | 越界 %% |\n|---|---|---:|---:|---:|---:|---:|---:|---:|\n');
 for k=1:height(task)
    r=task(k,:);fprintf(file,'| %s | %s | %.7g | %.7g | %.7g | %.7g | %.7g | %.5g | %.5g |\n', ...
        r.case_id,r.method,r.yaw_rmse_deg,r.attitude_rmse_deg,r.moment_model_error_rms_nm, ...
        r.saturation_percent,r.command_step_rms_deg,r.low_speed_regularized_percent,r.aero_extrapolated_percent);
    b=task(task.case_id=="M0" & task.method==r.method,:);if isempty(b), continue; end
    d=table(r.case_id,r.method,'VariableNames',{'case_id','method'});
    for name=["yaw_rmse_deg","attitude_rmse_deg","moment_model_error_rms_nm","moment_model_error_max_nm", ...
            "saturation_percent","mode1_percent","mode2_percent","command_step_rms_deg","low_speed_regularized_percent", ...
            "aero_extrapolated_percent","position_rmse_m"]
        d.("delta_"+name)=r.(name)-b.(name);
        d.("relative_"+name+"_percent")=100*(r.(name)/b.(name)-1);
    end
    relative=[relative;d]; %#ok<AGROW>
 end
 if ~isempty(relative), writetable(relative,fullfile(study.output_dir,'relative_to_M0.csv'),'Encoding','UTF-8'); end
end
fprintf(file,'\n位置误差保留为secondary；力矩误差包含气流标量和舵效失配。非PCA的mode比例不作为优先级机制比较。\n\n');
failed_rows=study.status(string(study.status.status)=="failed",:);
for k=1:height(failed_rows)
 fprintf(file,'失败%s/%s：%s；%s。\n\n',string(failed_rows.case_id(k)),string(failed_rows.method(k)), ...
    string(failed_rows.error_id(k)),string(failed_rows.error_message(k)));
end
fprintf(file,'案例定义、源码快照、输入种子、完整原始日志、失败与未运行项均保留。综合结论只回答是否出现结构可区分性，不以某方法胜出为结论；八项问题及低速验证见本轮总报告。\n');
end
