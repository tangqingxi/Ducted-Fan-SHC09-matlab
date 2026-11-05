function manifest=ppid_source_manifest(root)
% 固定公共引擎和新研究源码；新目录不在旧引擎摘要内，因此必须单独覆盖。
manifest=struct('engine',allocation_comparison_engine(root),'files',struct('path',{},'sha256',{}));
paths=[dir(fullfile(root,'studies','ppid_pindi','*.m'));dir(fullfile(root,'research','ppid_pindi','protocol.json'))];
% 旧引擎未覆盖轨迹实验函数和JSON，新增正式锁必须显式补齐。
paths=[paths;dir(fullfile(root,'studies','legacy_experiments','*.m'));dir(fullfile(root,'configs','*.json'))];
% 公共模块已经迁出研究目录，必须在显式来源中补齐，避免 engine 之外漏计。
paths=[paths;dir(fullfile(root,'src','control','ppid','*.m')); ...
    dir(fullfile(root,'src','navigation','ppid_estimator_init.m')); ...
    dir(fullfile(root,'src','sensors','ppid_noise.m'));dir(fullfile(root,'src','sensors','ppid_sensor_step.m')); ...
    dir(fullfile(root,'src','runtime','sim','ppid_simulate.m'))];
for relative=["ca_setup.m","run_ppid_pindi.m","analysis/allocation_comparison_hash.m","analysis/allocation_comparison_engine.m"]
    paths=[paths;dir(fullfile(root,relative))]; %#ok<AGROW>
end
for item=reshape(paths,1,[])
    path=fullfile(item.folder,item.name);fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    manifest.files(end+1)=struct('path',string(strrep(path,[root,filesep],'')),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
path=fullfile(root,'build','px4_ecl','px4_ecl_bridge.exe');fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
manifest.ekf_executable_sha256=allocation_comparison_hash(bytes,true);
end
