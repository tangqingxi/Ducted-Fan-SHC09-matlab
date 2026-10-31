function [front,valid] = estimated_pareto_front(x,y)
% 同时最小化两轴；保留数值平局，非有限点不参与前沿。
x=x(:);y=y(:);assert(numel(x)==numel(y));valid=isfinite(x)&isfinite(y);front=valid;
for k=1:numel(x)
 for j=1:numel(x)
  tol=1e-9*max([ones(1,2);abs([x(k),y(k)]);abs([x(j),y(j)])],[],1);
  if valid(k)&&valid(j)&&all([x(j),y(j)]<=[x(k),y(k)]+tol)&&any([x(j),y(j)]<[x(k),y(k)]-tol),front(k)=false;end
 end
end
end
