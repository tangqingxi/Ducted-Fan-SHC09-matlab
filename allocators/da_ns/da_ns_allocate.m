function [command,info] = da_ns_allocate(ctx)
% 薄包装只使用统一上下文，原算法实现不修改。
[command,info]=ca_da_ns(ctx.demand.v_h+ctx.demand.v_c,ctx.model.B,ctx.model,ctx.config);
info=allocator_info(info);
end
