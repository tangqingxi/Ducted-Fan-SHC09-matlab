function [command,info] = shc09_allocator_dispatch(name,ctx)
% 核心只识别注册契约，不包含任何方法名或优先级分支。
entries=registry();index=find([entries.name]==string(name),1);
assert(~isempty(index),'shc09:UnknownAllocator','分配器未注册：%s',name);
plugin=entries(index);manifest=plugin.manifest();
for required=reshape(manifest.requires,1,[])
    parts=split(required,'.');value=ctx;
    for part=reshape(parts,1,[])
        assert(isstruct(value) && isfield(value,part),'shc09:PluginContext','插件上下文缺少%s。',required);value=value.(part);
    end
end
started=tic;[command,info]=plugin.allocate(ctx);info.solve_time_s=toc(started);
assert(iscolumn(command) && numel(command)==size(ctx.model.B,2) && all(isfinite(command)), ...
    'shc09:PluginOutput','插件命令维度或有限性错误。');
for field=reshape(manifest.info_fields,1,[])
    assert(isfield(info,field),'shc09:PluginInfo','插件缺少状态字段%s。',field);
end
end
