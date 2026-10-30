function [command,info] = example_pinv_allocate(ctx)
% 最小范数伪逆示例；逐元素限幅不保证约束边界的需求方向。
target=ctx.demand.v_h+ctx.demand.v_c;
command=pinv(ctx.model.B)*target;
command=min(max(command,ctx.model.command_lower),ctx.model.command_upper);
info=struct('allocated_effect',ctx.model.B*command,'iterations',1,'exitflag',1,'mode',0);
end
