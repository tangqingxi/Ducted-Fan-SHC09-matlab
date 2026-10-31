function results = main_disturbance_benchmark(overrides)
% 单次随机扰动分级对比，与重复试验共享同一仿真和结果表结构。
ca_setup();
if nargin<1, overrides=struct(); end
settings=struct('num_repeats',1,'output_tag','shc09_6dof_random_single');
names=fieldnames(overrides);
for k=1:numel(names), settings.(names{k})=overrides.(names{k}); end
results=run_disturbance_benchmark(settings);
end
