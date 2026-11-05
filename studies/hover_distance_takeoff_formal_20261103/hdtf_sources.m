function sources=hdtf_sources(root)
% 单独冻结新数值来源；旧锁只读，后处理另记来源且不参与仿真。
sources=struct('base',hd_sources(root),'files',struct('path',{},'sha256',{}));
items=[dir(fullfile(root,'studies','hover_distance_takeoff_formal_20261103','*.m')); ...
    dir(fullfile(root,'research','hover_distance_takeoff_formal_20261103','protocol.json'))];
for relative=["studies/hover_distance_takeoff_20261103/hdt_reference.m","run_hover_distance_takeoff_formal.m", ...
        "analysis/export_windtrace_flight.m","tools/export_windtrace.py","tools/audit_windtrace.py"]
    items=[items;dir(fullfile(root,relative))]; %#ok<AGROW>
end
for item=reshape(items,1,[])
    path=fullfile(item.folder,item.name);fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    sources.files(end+1)=struct('path',string(strrep(path,[root,filesep],'')),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
end
