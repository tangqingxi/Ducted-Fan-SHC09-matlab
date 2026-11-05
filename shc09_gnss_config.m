function [cfg,model,ref,plan,spec]=shc09_gnss_config(seed,scenario)
% 后续研究的显式GNSS配置入口；旧正式入口和旧锁继续使用历史协议。
if nargin<2,scenario="f8";end
root=ca_setup();
addpath(fullfile(root,'studies','ppid_pindi','gnss_v2'));
[cfg,model,ref,plan,spec]=ppid_gnss_v2_config(seed,scenario);
end
