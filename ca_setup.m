function folder = ca_setup()
% 以自身位置确定根目录，只添加明确授权的源码路径。
folder = fileparts(mfilename('fullpath'));
% 每行先旧后新；逐行前置以保留旧布局的原有优先级。
layouts = {
    'configs/params', 'configs/params';
    'configs/airframes', 'configs/airframes';
    'apps', 'apps';
    'apps/experimental', 'apps/experimental';
    'apps/legacy', 'apps/legacy';
    'platform/logger', 'src/runtime/logger';
    'models/shc09', 'airframes/shc09';
    'drivers/actuators', 'src/drivers/actuators';
    'modules/state_estimator/px4_ecl', 'src/navigation/px4_ecl';
    'modules/control_allocator', 'allocators/interface';
    'lib/filters', 'src/lib/filters';
    'lib/math', 'src/lib/math';
    'experiments', 'studies/legacy_experiments';
    'analysis', 'analysis';
    'tests', 'tests';
    'platform', 'src/runtime';
    'platform/msg', 'src/runtime/msg';
    'platform/params', 'src/runtime/params';
    'platform/scheduler', 'src/runtime/scheduler';
    'platform/sim', 'src/runtime/sim';
    'platform/tests', 'src/runtime/tests';
    'allocators', 'allocators';
    'effectiveness', 'src/effectiveness';
    'compat', 'src/compat';
    'platform/modules/control_allocator', 'allocators/interface/control_allocator';
    'platform/modules/sensors', 'src/sensors/sensors';
    'platform/modules/estimator', 'src/navigation/estimator';
    'platform/modules/commander', 'src/control/commander';
    'platform/modules/position_control', 'src/control/position_control';
    'platform/modules/attitude_control', 'src/control/attitude_control';
    'platform/modules/rate_control', 'src/control/rate_control';
    'platform/modules/actuator_output', 'src/control/actuator_output';
    '', 'src/control/ppid';
    '', 'src/navigation';
    '', 'src/sensors';
    '', 'studies/ppid_pindi';
    '', 'dynamics/shc09/plant';
    '', 'dynamics/shc09/nonlinear_6dof';
    '', 'dynamics/shc09/hover_reduced_order';
    '', 'src/control/frame';
};
directories = {folder};
for k = 1:size(layouts,1)
    for j = 1:2
        if isempty(layouts{k,j}), continue; end
        candidate = fullfile(folder,layouts{k,j});
        if isfolder(candidate) && ~any(strcmp(directories,candidate))
            directories{end+1} = candidate; %#ok<AGROW>
        end
    end
end
% 添加前拒绝新旧布局的同名实现，避免依赖路径优先级静默选错。
assert_unique(directories);
for k = 1:numel(directories), addpath(directories{k},'-begin'); end
assert_resolution('registry',fullfile(folder,'allocators','registry.m'));
assert_resolution('effectiveness_registry',resolve_effect(folder,'effectiveness_registry.m'));
plugins = registry();
assert(numel(plugins)==6,'ca_setup:Registry','分配器注册条目必须保持六项。');
for plugin = plugins
    candidate = fullfile(folder,plugin.directory);
    assert(isfolder(candidate),'ca_setup:MissingPlugin','分配器目录不存在：%s',candidate);
    directories{end+1} = candidate; %#ok<AGROW>
end
effects = effectiveness_registry();
for effect = effects
    % 注册表仍可使用旧相对路径；迁移后的效能插件通过同一映射查找。
    candidate = fullfile(folder,effect.directory);
    migrated = fullfile(folder,'src',effect.directory);
    if isfolder(migrated), candidate = migrated; end
    assert(isfolder(candidate),'ca_setup:MissingPlugin','效能目录不存在：%s',candidate);
    directories{end+1} = candidate; %#ok<AGROW>
    if isfolder(fullfile(folder,effect.directory)) && isfolder(migrated)
        directories{end+1} = fullfile(folder,effect.directory); %#ok<AGROW>
    end
end
assert_unique(directories);
for k = 1:numel(directories), addpath(directories{k},'-begin'); end
% 检查当前目录或外部路径遮蔽；只解析文件，不调用控制算法。
for k = 1:numel(directories)
    files = dir(fullfile(directories{k},'*.m'));
    for item = reshape(files,1,[])
        [~,name] = fileparts(item.name);
        assert_resolution(name,fullfile(item.folder,item.name));
    end
end
end

function target = resolve_effect(root,name)
% 同名候选已由唯一性检查拦截。
target = fullfile(root,'effectiveness',name);
if isfile(fullfile(root,'src','effectiveness',name))
    target = fullfile(root,'src','effectiveness',name);
end
end

function assert_unique(directories)
% 只扫描显式目录直属文件，不扫描冻结参考、私有目录或整个仓库。
names = {}; locations = {};
for k = 1:numel(directories)
    files = dir(fullfile(directories{k},'*.m'));
    for item = reshape(files,1,[])
        target = fullfile(item.folder,item.name);
        previous = find(strcmpi(names,item.name),1);
        if ~isempty(previous)
            assert(strcmpi(locations{previous},target),'ca_setup:DuplicateFunction', ...
                '同名实现必须先明确处理：%s 与 %s',locations{previous},target);
        else
            names{end+1} = item.name; locations{end+1} = target; %#ok<AGROW>
        end
    end
end
end

function assert_resolution(name,expected)
% MATLAB 实际解析是权威依据；保留路径外历史副本，但不允许其获选。
actual = which(name);
assert(strcmpi(strrep(actual,'\','/'),strrep(expected,'\','/')), ...
    'ca_setup:ShadowedFunction','函数 %s 解析异常：%s；预期 %s',name,actual,expected);
end
