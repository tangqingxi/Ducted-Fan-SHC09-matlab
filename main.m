function results = main(allocator_flag,overrides)
% 单算法主入口：只改变分配器标志，其余物理对象与控制器保持相同。
% 示例：main(5)；main("DCA",struct('duration_s',6))；main(3,struct('flight_mode',"position_hold"))。
ca_setup();
if nargin<1, allocator_flag=5; end
if nargin<2, overrides=struct(); end
method=ca_allocator_name(allocator_flag);
overrides.methods=method;
if ~isfield(overrides,'output_tag')
    overrides.output_tag=char("shc09_"+lower(method)+"_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
results=main_comparison(overrides);
end
