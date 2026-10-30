function [command,info] = pca_predictive_allocate(ctx)
% 薄包装只使用统一上下文，原算法实现不修改。
[command,info]=ca_pca_predictive(ctx.demand.v_h,ctx.demand.v_c,ctx.model.B,ctx.state.delta_hat,ctx.model,ctx.config,ctx.timing);
info=allocator_info(info);
end
