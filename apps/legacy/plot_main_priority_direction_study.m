function figures = plot_main_priority_direction_study(result_path,show_figures)
% 从单个固定或变化方向场景结果重绘，不运行仿真。
ca_setup();
if nargin<2, show_figures=true; end
figures=plot_priority_direction_study(result_path,show_figures);
end
