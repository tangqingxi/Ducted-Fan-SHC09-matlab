function results = plot_main_comparison(result_path,show_figures)
% 为原统一入口补充离线绘图，不重复仿真。
folder=ca_setup();
if nargin<2, show_figures=true; end
if nargin<1, result_path=fullfile(folder,'results','shc09_6dof_meng_pwm333'); end
if isfolder(result_path), file=fullfile(result_path,'comparison.mat'); else, file=result_path; end
assert(isfile(file),'结果文件不存在：%s',file);
data=load(file,'results');
results=data.results;
results.config.show_figures=show_figures;
ca_plot(results,fileparts(file));
fprintf('已重绘姿态、分配诊断及可用的物理状态图，保存位置：%s\n',fileparts(file));
end
