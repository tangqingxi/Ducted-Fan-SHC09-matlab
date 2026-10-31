function value = allocation_comparison_hash(data,raw_bytes)
% 对配置、输入或源码字节做确定性摘要，缓存不能仅凭文件名复用。
digest=java.security.MessageDigest.getInstance('SHA-256');
if nargin>1&&raw_bytes,bytes=uint8(data);else,bytes=getByteStreamFromArray(data);end
digest.update(typecast(bytes,'int8'));
value=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[])));
end
