function study=run_hover_distance(stage,varargin)
% 独立悬停偏差工况入口，复用既有四环控制器，不修改旧协议或驱动。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
study=hd_run(stage,varargin{:});
end
