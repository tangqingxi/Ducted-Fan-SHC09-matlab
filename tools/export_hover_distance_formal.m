function result=export_hover_distance_formal(output)
% 从完整原始MAT只读导出所有15条时序，包括被旧单位检查拒绝的条目。
root=ca_setup();addpath(fullfile(root,'studies','hover_distance'));
destination=fullfile(output,'visualization');assert(~isfolder(destination));mkdir(destination);
mkdir(fullfile(destination,'tracks'));mkdir(fullfile(destination,'allocation_tracks'));count=0;
for seed=[501,502,503],for method=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"]
    path=fullfile(output,'logs',sprintf('%s_s%d.mat',method,seed));if ~isfile(path),continue;end
    d=load(path,'L','ref');L=d.L;assert(numel(L.time_s)==32001&&L.time_s(end)==40);
    hd_write_track(destination,L,d.ref,seed);trackpath=fullfile(destination,'tracks',sprintf('%s_s%d.csv',method,seed));
    T=readtable(trackpath);keep=1:8:numel(L.time_s);
    for axis=1:3,T.("true_rate_"+axis)=rad2deg(L.omega(keep,axis));end
    writetable(T,trackpath);k=find(L.control_updated);
    A=table(L.time_s(k),L.lambda(k),L.mode(k),'VariableNames',{'time_s','lambda','mode'});
    writetable(A,fullfile(destination,'allocation_tracks',sprintf('%s_s%d.csv',method,seed)));count=count+1;
end,end
result=struct('logs_exported',count,'state_display_hz',100,'allocation_display_hz',400,'flight_simulations_run',0);
fid=fopen(fullfile(destination,'export_checks.json'),'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));fclose(fid);disp(result);
end
