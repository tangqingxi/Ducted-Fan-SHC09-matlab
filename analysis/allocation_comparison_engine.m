function fingerprint = allocation_comparison_engine(root)
% 仅摘要仓库数值引擎，不访问结果目录或外部工程；报告代码变化不使数值缓存失效。
folders=["platform","allocators","effectiveness","models","drivers","lib","configs","modules","compat"];
paths=string.empty;
for folder=folders
 entries=dir(fullfile(root,folder,'**','*.m'));
 for item=reshape(entries,1,[]),paths(end+1)=string(fullfile(item.folder,item.name));end
end
paths=sort([paths,string(fullfile(root,'experiments','ca_mismatch_protocol.m'))]);
parts=cell(numel(paths),2);
for k=1:numel(paths)
 fid=fopen(paths(k),'rb');assert(fid>=0);clean=onCleanup(@()fclose(fid));
 parts{k,1}=erase(paths(k),string(root)+filesep);parts{k,2}=fread(fid,Inf,'*uint8');clear clean;
end
fingerprint=allocation_comparison_hash(parts);
% v0.3.0冻结气动表沿用既有命名空间；任何表内容变化都加入摘要，不能命中旧日志。
tables=["duct_raw.mat","wing_raw.mat"];
canonical=["a5140eea72b98021433af2b1cb3b94b3660700eb84834751c102f07cf1831d2a","299bbd2b6b6e0a60bc463bce89ddd240bb933c498d0bab2b331a8f54e98d15b2"];
observed=strings(1,2);
for k=1:2
 fid=fopen(fullfile(root,'models','shc09','reference',tables(k)),'rb');assert(fid>=0);clean=onCleanup(@()fclose(fid));
 observed(k)=allocation_comparison_hash(fread(fid,Inf,'*uint8'),true);clear clean;
end
if ~isequal(observed,canonical),fingerprint=allocation_comparison_hash({parts,observed});end
end
