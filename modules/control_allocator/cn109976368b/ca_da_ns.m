function [command,info] = ca_da_ns(target,B,model,cfg)
% 按专利步骤先直接分配，再求伪逆及零空间修正；适用本平台对称幅值界。
persistent options
if isempty(options), options=optimoptions('linprog','Display','none'); end
lo = model.command_lower;
hi = model.command_upper;
if norm(target,Inf)<1e-12
    command=zeros(6,1);
    info=struct('allocated_effect',B*command,'direction_scale',1,'iterations',0,'exitflag',1,'mode',0);
    return;
end
[solution,~,flag,output] = linprog([zeros(6,1);-1],[],[], ...
    [B,-target],zeros(3,1),[lo;0],[hi;Inf],options);
assert(flag>0,'直接分配线性规划失败。');
rho=solution(7);
scale=min(1,rho);
assigned=scale*target;
command=pinv(B)*assigned;
N=null(B);
width=hi-lo;
iteration=0;
mode=0;
degenerate=false;
while any(command<lo-cfg.constraint_tolerance | command>hi+cfg.constraint_tolerance) && iteration<cfg.max_iterations
    iteration=iteration+1;
    % 按原文定义分段偏置和尺度，超下界时改从上界反向度量。
    H=width;
    G=lo;
    below=command<lo;
    H(below)=-width(below);
    G(below)=hi(below);
    normalized=(command-G)./H;
    h=max(normalized);
    active=find(abs(normalized-h)<=1e-10);
    Ns=N(active,:);
    rhs=H(active)/abs(H(active(1)));
    % 多个并列极值可能使矩阵奇异，用广义逆并显式记录该数值适配。
    gram=Ns*Ns';
    if rcond(gram)<1e-12, degenerate=true; end
    direction=N*Ns'*pinv(gram)*rhs;
    slope=direction./H;
    first=active(1);
    remaining=setdiff((1:6)',active);
    denominator=slope(first)-slope(remaining);
    candidates=(normalized(first)-normalized(remaining))./denominator;
    candidates=candidates(isfinite(candidates) & candidates>1e-12);
    endpoint=abs(command(first)-(H(first)+G(first)));
    step=min([candidates;endpoint]);
    if isempty(step) || step<1e-14 || norm(direction)<1e-14, break; end
    command=command-direction*step;
end
if any(command<lo-cfg.constraint_tolerance | command>hi+cfg.constraint_tolerance)
    % 原文的迭代超限缩放；对称界下保持方向，明确记录额外缩减。
    command=command/max(1,max(abs(command)./hi));
    mode=1;
end
info=struct('allocated_effect',B*command,'direction_scale',scale, ...
    'iterations',iteration+output.iterations,'exitflag',flag,'mode',mode, ...
    'nullspace_degenerate',degenerate,'equality_error',norm(B*command-assigned,Inf));
end
