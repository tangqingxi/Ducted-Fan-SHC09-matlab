function signature = shc09_log_signature(log)
% 用完整非耗时字段的SHA256冻结数值；新增日志字段不影响旧字段比较。
fields=string(fieldnames(log));excluded=["elapsed_s","solve_time_s", ...
    "navigation_warmup_elapsed_s","navigation_step_time_s"];
signature=struct();
for field=reshape(fields,1,[])
    if ismember(field,excluded),continue;end
    value=log.(field);bytes=getByteStreamFromArray(value);
    digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
    raw=typecast(digest.digest(),'uint8');signature.(field)=lower(reshape(dec2hex(raw,2)',1,[]));
end
end
