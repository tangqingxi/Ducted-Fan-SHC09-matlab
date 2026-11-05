function sources=hft_sources(root)
% 单独冻结本次研究文件，原引擎、旧协议及旧来源锁保持原样。
sources=struct('base',hd_sources(root),'files',struct('path',{},'sha256',{}));
folder=fullfile(root,'studies','hover_distance_filter_20261102');items=[dir(fullfile(folder,'*.m'));dir(fullfile(folder,'*.json'))];
items=[items;dir(fullfile(root,'studies','hover_distance_formal_20261102','hdf_metrics.m'));dir(fullfile(root,'research','hover_distance_filter_20261102','protocol.json'))];
for item=reshape(items,1,[])
    path=fullfile(item.folder,item.name);fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    sources.files(end+1)=struct('path',string(strrep(path,[root,filesep],'')),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
end
