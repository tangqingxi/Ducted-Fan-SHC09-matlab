function study=run_ppid_pindi(stage,varargin)
% 新研究独立入口；旧仿真、冻结协议及默认路径保持不变。
root=ca_setup();addpath(fullfile(root,'studies','ppid_pindi'));
study=ppid_run_study(stage,varargin{:});
end
