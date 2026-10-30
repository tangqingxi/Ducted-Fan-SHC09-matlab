function [command,info] = ca_wls(target,B,delta_hat,model,cfg)
% Smeur式增量WLS：偏角对称平台的零输入对应首选增量负当前偏角。
lo=model.command_lower-delta_hat;
hi=model.command_upper-delta_hat;
scale=sum(abs(B).*model.command_upper',2);
Wv=diag(cfg.wls_axis_weights(:)./scale);
Wu=cfg.wls_input_weight*diag(1./model.command_upper);
increment_target=target-B*delta_hat;
A=[sqrt(cfg.wls_gamma)*Wv*B;Wu];
b=[sqrt(cfg.wls_gamma)*Wv*increment_target;Wu*(-delta_hat)];
[increment,working,iteration,optimal] = ca_wls_active_set(A,b,lo,hi,cfg.max_iterations);
command=delta_hat+increment;
info=struct('allocated_effect',B*command,'iterations',iteration, ...
    'exitflag',double(optimal),'mode',double(~optimal),'active_set',working, ...
    'objective',norm(A*increment-b)^2);
end
