function seed = ca_stable_seed(base,varargin)
% 借鉴参考项目的稳定字符串散列；种子键不含方法名，使同次试验公平配对。
seed=double(base);
for k=1:numel(varargin)
    token=char(string(varargin{k}));
    for j=1:numel(token), seed=mod(seed*33+double(token(j)),2^31-1); end
end
seed=mod(round(seed),2^31-1);
end
