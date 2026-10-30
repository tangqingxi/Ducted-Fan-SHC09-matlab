function folder = ca_setup()
% 只加入本次独立目录，不依赖原仓库或旧仿真的搜索路径。
folder = fileparts(mfilename('fullpath'));
paths={'config','models/shc09','drivers/actuators','modules/sensors', ...
    'modules/state_estimator','modules/state_estimator/px4_ecl','modules/mc_pos_control','modules/mc_att_control', ...
    'modules/mc_rate_control','modules/control_allocator','lib/filters','lib/math', ...
    'simulation','experiments','analysis','tests','platform','platform/msg', ...
    'platform/params','platform/scheduler','platform/sim','platform/tests','platform/modules/sensors','platform/modules/estimator','platform/modules/commander','platform/modules/position_control','platform/modules/attitude_control','platform/modules/rate_control','platform/modules/actuator_output'};
addpath(folder);
for k=1:numel(paths)
    path=fullfile(folder,paths{k});
    if isfolder(path), addpath(path); end
end
for name={'cn109976368b','smeur_wls','venkataraman_dca','pca_static','pca_predictive'}
    addpath(fullfile(folder,'modules','control_allocator',name{1}));
end
end
