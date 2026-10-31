function summary = main_candidate_screen(overrides)
% 三个预定八字或定点抗扰工况的五算法有限搜索入口。
ca_setup(); if nargin<1, overrides=struct(); end
summary=run_candidate_screen(overrides);
end
