function study = m4_load_sweep_app(varargin)
% 先固定门禁，再对三个负载做单种子扫描；不输出方法排名。
root=ca_setup();p=inputParser;addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));addParameter(p,'use_cached',false);parse(p,varargin{:});o=p.Results;
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
c=ca_config();plan=table();
for load_value=[0.4,0.5,0.6],for mode=["ideal","lite"],for method=c.methods
 plan=[plan;table("M4",load_value,mode,1,method,20,false,'VariableNames',{'case_id','load_fraction','estimator_mode','seed','method','duration_s','smoke_test'})];
end,end,end
options=struct('reuse_from',"",'use_cached',o.use_cached,'fail_fast',false);
out=fullfile(root,'results','m4_load_sweep_'+string(o.output_tag));study=allocation_comparison_run(plan,out,options);C=study.comparability;
valid=C.load_fraction(C.estimator_mode=="lite" & C.comparability=="rankable");selected=NaN;
% 最高负载须两模式均通过；最低档仍失败时不通过其他档绕过指定退路。
low=C(C.load_fraction==0.4 & C.estimator_mode=="lite",:);
if ~isempty(low)&&low.comparability=="rankable"
 for load_value=reshape(sort(valid,'descend'),1,[])
  q=C.load_fraction==load_value;if all(C.comparability(q)=="rankable"),selected=load_value;break;end
 end
end
study.selected_m4_load=selected;fid=fopen(fullfile(out,'selection.json'),'w','n','UTF-8');
selection=struct('selected_m4_load',selected,'has_comparable_m4',isfinite(selected),'seeds',1,'source_output',string(out),'rule',"固定门禁，最低0.4通过后选两模式最高可比负载；0.6另保留压力参考");fprintf(fid,'%s',jsonencode(selection,PrettyPrint=true));fclose(fid);
fid=fopen(fullfile(out,'report.md'),'w','n','UTF-8');fprintf(fid,'# M4 可比负载扫描\n\n单种子、只评价可比性，不比较或排名方法。门禁在扫描前固定：五方法全部完成、主窗任一方法饱和≤10%%、姿态峰值≤5°、气动越界=0、lite姿态估计RMS≤2°。位置峰值仅报告。\n\n|负载|模式|完成方法|饱和%%最大|姿态峰值°|位置峰值m|估计姿态RMS°|可比性|原因|\n|---|---|---:|---:|---:|---:|---:|---|---|\n');
for k=1:height(C),fprintf(fid,'|%.1f|%s|%d|%.6g|%.6g|%.6g|%.6g|%s|%s|\n',C.load_fraction(k),C.estimator_mode(k),C.completed_methods(k),C.max_saturation_percent(k),C.max_attitude_error_deg(k),C.max_position_error_m(k),C.attitude_estimate_rmse_deg(k),C.comparability(k),C.reason(k));end
if isfinite(selected),fprintf(fid,'\n选定最高可比负载：%.1f。三种子主比较仍重新按最坏种子评价，单种子通过不保证三种子通过。\n',selected);else,fprintf(fid,'\nM4 在当前 lite 下没有可比负载。主比较只用M0/M2b，M4仅作压力演示；未改变tanh、协议或阈值。\n');end
fprintf(fid,'\n默认ideal、lite experimental、偏置门禁仍失败、tau匹配、无实机。失败及未运行见status，气动域失败为invalid，不改record、不真值兜底。\n');fclose(fid);
save(fullfile(out,'study.mat'),'study','-v7');
end
