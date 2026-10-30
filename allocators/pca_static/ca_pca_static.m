function [command,info] = ca_pca_static(v_h,v_c,B,delta_hat,model,cfg,timing)
% 保留原静态优先级线性规划、零空间恢复及显式回退。
[command,info] = ca_priority_core(v_h,v_c,B,delta_hat,model,cfg,false,timing);
info.beta = NaN;
if info.mode==1, info.beta=info.lambda; info.lambda=NaN; end
end
