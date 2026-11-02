function manifest=hd_sources(root)
% 新场景扩展锁覆盖；父控制器、传感器、PWM及当前公共引擎均纳入来源记录。
manifest=struct('parent',ppid_source_manifest(root),'files',struct('path',{},'sha256',{}));
paths=[dir(fullfile(root,'research','hover_distance','*.m'));dir(fullfile(root,'research','hover_distance','protocol.json')); ...
    dir(fullfile(root,'research','ppid_pindi','formal_lock.json'));dir(fullfile(root,'run_hover_distance.m'))];
for item=reshape(paths,1,[])
    path=fullfile(item.folder,item.name);fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    manifest.files(end+1)=struct('path',string(strrep(path,[root,filesep],'')),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
end
