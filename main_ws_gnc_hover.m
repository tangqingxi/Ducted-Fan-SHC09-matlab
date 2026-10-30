function summary = main_ws_gnc_hover(overrides)
% 定点悬停与横向正弦力矩扫幅，比较五种分配器。
ca_setup();
if nargin<1, overrides=struct(); end
summary=run_ws_gnc_hover_comparison(overrides);
end
