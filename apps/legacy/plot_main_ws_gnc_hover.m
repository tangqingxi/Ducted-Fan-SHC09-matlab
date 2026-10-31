function figures = plot_main_ws_gnc_hover(result_path,show_figures)
% 从已保存的悬停扫幅结果重绘，不重新运行仿真。
ca_setup();
if nargin<2, show_figures=true; end
figures=plot_ws_gnc_hover_comparison(result_path,show_figures);
end
