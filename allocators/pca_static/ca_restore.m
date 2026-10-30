function [u_rest] = ca_restore(B,u,uMin,uMax)
% 来源：restoring/restoring_cpp.m；独立副本，原文件未修改。
tol=0.00001;
if(all(abs(u) < tol))
    u_rest=u;
    return;
end

[~,m] = size(B);

uMin_new=uMin-u;
uMax_new=uMax-u;

a=-2;
u_pseudo = B' * ((B*B') \ (B*u));
u_null_component = u - u_pseudo;
u_null_component_norm_squared = u_null_component' * u_null_component;
if(u_null_component_norm_squared < tol^2)
    u_rest=u;
    return;
end
u_null = a * u_null_component / u_null_component_norm_squared;


K_opt=-a/(u_null'*u_null);


K_max=Inf;
for i=1:m
    if(abs(u_null(i))<tol)
        continue;
    end
    if(u_null(i)>0)
        tmp=uMax_new(i)/u_null(i);
    else
        tmp=uMin_new(i)/u_null(i);
    end
    if(tmp<K_max)
        K_max=tmp;
    end
end

if K_max<K_opt
    u_rest = u + K_max*u_null;
else
    u_rest = u + K_opt*u_null;
end

end
