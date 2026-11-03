function sources=hdt_sources(root)
% 新变体单独锁定源码和后处理来源，不更新任何旧锁。
sources=struct('base',hd_sources(root),'files',struct('path',{},'sha256',{}));
items=[dir(fullfile(root,'research','hover_distance_takeoff_20261103','*.m')); ...
    dir(fullfile(root,'research','hover_distance_takeoff_20261103','protocol.json'))];
for relative=["run_hover_distance_takeoff.m","tools/plot_hover_distance_takeoff.py", ...
        "analysis/export_windtrace_flight.m","tools/export_windtrace.py","tools/audit_windtrace.py"]
    items=[items;dir(fullfile(root,relative))]; %#ok<AGROW>
end
for item=reshape(items,1,[])
    path=fullfile(item.folder,item.name);fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    sources.files(end+1)=struct('path',string(strrep(path,[root,filesep],'')),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
end
