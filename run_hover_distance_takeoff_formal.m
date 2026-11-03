function result=run_hover_distance_takeoff_formal(output_tag)
% 先一条最终时间线预检，通过才一次性运行五方法三种子，不重试或调参。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'),fullfile(root,'research','hover_distance'), ...
    fullfile(root,'research','hover_distance_takeoff_20261103'),fullfile(root,'research','hover_distance_takeoff_formal_20261103'));
result=hdtf_run(output_tag);
end
