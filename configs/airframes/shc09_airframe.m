function overrides = shc09_airframe(mode)
% 显式悬停预设；保留ca_config历史默认，不暗改物理或比较协议。
overrides=struct('duration_s',2,'flight_mode',"position_hold", ...
 'initial_position_ned_m',[0;0;-10],'position_reference_ned_m',[0;0;-10], ...
 'aero_low_speed_model',"hold_90",'aero_extrapolation_policy',"error", ...
 'show_figures',false,'save_figures',false,'save_results',false);
if nargin>0
 assert(isscalar(string(mode)) && ismember(string(mode),["ideal","lite","px4_ecl"]),'未知估计预设。');
 overrides.estimator_mode=string(mode);
 if string(mode)=="px4_ecl",overrides.navigation_warmup_s=15;end
end
end
