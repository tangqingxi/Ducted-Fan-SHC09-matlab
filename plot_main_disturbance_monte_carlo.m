function summary = plot_main_disturbance_monte_carlo(result_path,show_figures)
% 只从已保存文件重绘；不调用任何分配器、随机生成器或动力学积分。
folder=ca_setup();
if nargin<2, show_figures=true; end
if nargin<1, result_path=fullfile(folder,'results','benchmark','shc09_6dof_random_mc'); end
if isfolder(result_path), file=fullfile(result_path,'benchmark.mat'); else, file=result_path; end
assert(isfile(file),'结果文件不存在：%s',file);
data=load(file,'results','cfg');
summary=render_disturbance_benchmark(data.results,data.cfg,fileparts(file),show_figures);
fprintf('已读取保存结果，重绘%d张图；未重跑仿真。\n',numel(data.cfg.scenarios));
fprintf('图片保存位置：%s\n',fullfile(fileparts(file),'figures'));
if ~show_figures, fprintf('当前为后台绘图模式，图窗未保留；显示图窗请将第二个参数设为true。\n'); end
end
