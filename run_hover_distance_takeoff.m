function study=run_hover_distance_takeoff(output_tag)
% 单条起飞预检独立入口；没有正式批或重试分支。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
addpath(fullfile(root,'research','hover_distance_takeoff_20261103'));
study=hdt_run(output_tag);
end
