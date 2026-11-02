function output=export_hover_filter_baseline(output)
% 原标称批只读重算残差，不改旧MAT、旧状态表或任何旧检查记录。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
addpath(fullfile(root,'research','hover_distance_formal_20261102'));addpath(fullfile(root,'research','hover_distance_filter_20261102'));
assert(~isfolder(output));mkdir(output);rows=table();
for seed=[501,502,503],for method=["PCA_PREDICTIVE","DCA"]
    d=load(fullfile(root,'results','hover_distance_formal_20261102_r1','logs',sprintf('%s_s%d.mat',method,seed)));
    m=hft_metrics(d.L,d.cfg,d.model,d.ref,d.plan,seed,8,8);rows=[rows;struct2table(m,'AsArray',true)]; %#ok<AGROW>
end,end
writetable(rows,fullfile(output,'nominal_metrics.csv'));
fid=fopen(fullfile(output,'read_only_checks.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(struct('logs_read',6,'old_files_written',0,'flight_simulations_run',0),PrettyPrint=true));fclose(fid);
end
