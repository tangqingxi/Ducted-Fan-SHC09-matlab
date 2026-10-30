function results = main_comparison(overrides)
% 保留旧入口签名与输出，委托平台运行。
if nargin<1,overrides=struct();end
results=shc09_run(overrides);
end
