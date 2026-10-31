function figures = plot_main_priority_pilot(result_path,show_figures)
% 读取结果重新显示，不重跑控制器或物理对象。
ca_setup();
if nargin<2, show_figures=true; end
figures=plot_priority_pilot(result_path,show_figures);
end
