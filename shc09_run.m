function results = shc09_run(overrides)
% 面向平台的公共入口，旧main包装继续使用相同参数与返回值。
if nargin<1,overrides=struct();end
ca_setup();results=platform_run(overrides);
end
