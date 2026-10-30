function m = pca_static_manifest()
% 声明输入契约、状态字段和能力，不读取配置真值。
m=allocator_manifest("PCA_STATIC",["demand.v_h","demand.v_c","state.delta_hat","model.B","timing","config"],true);
end
