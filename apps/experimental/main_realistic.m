function results = main_realistic(allocator_flag,overrides)
% 非理想导航和真实时变执行器下的单方法入口，标志仍为一到五。
ca_setup(); if nargin<1, allocator_flag=5; end
if nargin<2, overrides=struct(); end
overrides.methods=ca_allocator_name(allocator_flag);
results=main_realistic_comparison(overrides);
end
