# 兼容接口

`ca_complete_allocation.m` 为历史分配器接口保留兼容层，由 `allocators/interface/ca_allocate.m` 在旧调用路径中调用。它只补充旧日志字段和公共预测残差，不决定插件类型，也不改变控制/分配数值。

`ca_setup` 通过 `src/compat` 显式加入搜索路径；旧根目录 `compat/` 已移除。历史来源锁若记录旧文件 SHA，不因本次路径迁移而改写。
