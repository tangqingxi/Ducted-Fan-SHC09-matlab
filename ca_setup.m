function folder = ca_setup()
% 只加入本次独立目录，不依赖原仓库或旧仿真的搜索路径。
folder = fileparts(mfilename('fullpath'));
paths={'configs/params','configs/airframes','apps','apps/experimental','apps/legacy','platform/logger','models/shc09','drivers/actuators','modules/state_estimator/px4_ecl','modules/control_allocator','lib/filters','lib/math', ...
    'experiments','analysis','tests','platform','platform/msg', ...
    'platform/params','platform/scheduler','platform/sim','platform/tests','allocators','effectiveness','compat','platform/modules/control_allocator','platform/modules/sensors','platform/modules/estimator','platform/modules/commander','platform/modules/position_control','platform/modules/attitude_control','platform/modules/rate_control','platform/modules/actuator_output'};
addpath(folder);
for k=1:numel(paths)
    path=fullfile(folder,paths{k});
    if isfolder(path), addpath(path); end
end
plugins=registry();
for plugin=plugins,addpath(fullfile(folder,plugin.directory));end
effects=effectiveness_registry();
for effect=effects,addpath(fullfile(folder,effect.directory));end
end
