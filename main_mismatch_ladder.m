function study = main_mismatch_ladder(overrides)
% 第一阶段结构失配实验入口；控制器和分配器保持原实现。
ca_setup();
if nargin<1, overrides=struct(); end
study=run_mismatch_ladder(overrides);
end
