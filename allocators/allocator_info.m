function info = allocator_info(info)
% 补齐旧入口原有的通用默认状态，不改变算法本体或已有字段。
defaults=struct('iterations',NaN,'exitflag',1,'mode',0);
for field=reshape(string(fieldnames(defaults)),1,[])
    if ~isfield(info,field),info.(field)=defaults.(field);end
end
end
