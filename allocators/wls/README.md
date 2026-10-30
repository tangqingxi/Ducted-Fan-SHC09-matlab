# 增量WLS

已实现`ca_wls.m`和`ca_wls_active_set.m`，参考原库`QP_allocator/wls_alloc_gen.m`。默认三轴归一化权重为[1000,1000,1]，gamma为1e8，首选零舵角。来源及删除推力通道等适配见上级`method_adaptations.md`。方法标识为`WLS`。
