function [command,info] = ca_allocate(method,v_h,v_c,delta_hat,model,cfg,timing)
% 保留旧签名，实际算法完全由显式注册表分派。
ctx=shc09_allocator_context(v_h,v_c,delta_hat,model,cfg,timing);
[command,info]=shc09_allocator_dispatch(method,ctx);
info=ca_complete_allocation(info,command,v_h,v_c,delta_hat,ctx.model,ctx.config,timing);
end
