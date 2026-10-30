function m = example_pinv_manifest()
% 第六个插件与平台核心无特殊耦合。
m=allocator_manifest("EXAMPLE_PINV",["demand.v_h","demand.v_c","model.B"],false);
end
