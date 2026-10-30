function [u,W,iteration,optimal] = ca_wls_active_set(A,b,lo,hi,max_iterations)
% 参照原库QP_allocator/wls_alloc_gen.m的有界最小二乘活动集算法。
% 增加最优性、迭代数返回，使用可行中点初始化及尺度相关乘子容差。
u=(lo+hi)/2;
W=zeros(numel(u),1);
optimal=false;
for iteration=1:max_iterations
    free=W==0;
    residual=b-A*u;
    p=zeros(size(u));
    p(free)=A(:,free)\residual;
    candidate=u+p;
    if all(candidate(free)>=lo(free)-1e-12 & candidate(free)<=hi(free)+1e-12)
        u=candidate;
        gradient=A'*(A*u-b);
        active=find(W~=0);
        multipliers=-W(active).*gradient(active);
        tolerance=1e-9*max(1,norm(A,'fro')*norm(A*u-b));
        if isempty(active) || all(multipliers>=-tolerance)
            optimal=true;
            return;
        end
        [~,release]=min(multipliers);
        W(active(release))=0;
    else
        distance=Inf(size(u));
        downward=free & p<0;
        upward=free & p>0;
        distance(downward)=(lo(downward)-u(downward))./p(downward);
        distance(upward)=(hi(upward)-u(upward))./p(upward);
        [alpha,hit]=min(distance);
        u=u+max(0,min(1,alpha))*p;
        W(hit)=sign(p(hit));
        if W(hit)>0, u(hit)=hi(hit); else, u(hit)=lo(hit); end
    end
end
end
