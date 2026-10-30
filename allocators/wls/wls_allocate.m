function [command,info] = wls_allocate(ctx)
% 薄包装只使用统一上下文，原算法实现不修改。
[command,info]=ca_wls(ctx.demand.v_h+ctx.demand.v_c,ctx.model.B,ctx.state.delta_hat,ctx.model,ctx.config);
info=allocator_info(info);
end
