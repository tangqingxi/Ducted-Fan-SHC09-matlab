function summary = plot_main_disturbance_benchmark(result_path,show_figures)
% 单次与重复试验共用结果结构，均可离线重绘。
folder=ca_setup();
if nargin<2, show_figures=true; end
if nargin<1, result_path=fullfile(folder,'results','benchmark','shc09_6dof_random_single'); end
summary=plot_main_disturbance_monte_carlo(result_path,show_figures);
end
