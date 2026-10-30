function [command,info] = dca_allocate(ctx)
% 薄包装只使用统一上下文，原算法实现不修改。
[command,info]=ca_dca(ctx.demand.v_h+ctx.demand.v_c,ctx.state.delta_hat,ctx.model,ctx.config);
info=allocator_info(info);
end
