function ctx = shc09_allocator_context(v_h,v_c,delta_hat,model,cfg,timing)
% 白名单在旧调用入口也强制执行，调用者不能把完整cfg/model交给插件。
ctx=struct('demand',struct('v_h',v_h,'v_c',v_c),'state',struct('delta_hat',delta_hat), ...
 'model',effectiveness_for_model(model,cfg),'timing',timing,'config',ca_allocator_config(cfg));
end
