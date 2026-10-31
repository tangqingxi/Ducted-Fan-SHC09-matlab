function results = main_restore_ab(overrides)
% 在已保存的方向变化协议上配对比较原恢复和最小命令变化恢复。
ca_setup(); if nargin<1, overrides=struct(); end
results=run_restore_ab(overrides);
end
