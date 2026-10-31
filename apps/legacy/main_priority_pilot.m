function results = main_priority_pilot(overrides)
% 偏航负载与横向位置机动的五方法先行实验，不按算法表现调整公共参数。
ca_setup();
if nargin<1, overrides=struct(); end
results=run_priority_pilot(overrides);
end
