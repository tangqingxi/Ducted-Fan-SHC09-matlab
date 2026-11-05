# 分配架构决定 ADR-C3-W2-v1

日期：2026-11-05。状态：**最终目标架构已统一；实际C3执行待批准**。按用户本轮明确决定，不再把历史allocators/plugins候选视为有效执行方案。

基准DEV 269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1；科学基准339d7b1a997de6ba350cef3207d8a5b7db3d838d。适用范围：原W2的39项及相关接口归属。

```text
allocators/
  registry.m
  interface/              C2已迁移的六份接口实现保留原位
  da_ns/ wls/ dca/ pca_static/ pca_predictive/ example_pinv/
src/
  allocation/             仅保留现有规划README，不复制已有实现
  effectiveness/          计划接收五份效能源码；现有README保留
```

六注册项DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE、EXAMPLE_PINV及其算法、包装、manifest、目录和句柄不变；五正式算法与示例插件的身份边界不变。顶层registry不搬、不改内容。现有allocators/interface六份实现不属于本W2的33项，不再次移动；也不复制到src/allocation。

[W2_RESOLVED_PLAN.csv](W2_RESOLVED_PLAN.csv)是W2唯一有效执行单v1，SHA256 `e2a63faf87830338df97e172e95a1b3036c33c1a5e5832244565f929529a7e4f`，绑定当前DEV HEAD。原33项分配器文件全部KEEP，目标改为source_path本身；禁止创建allocators/plugins目录。效能五份MOVE，README仅延期文件移动。

原Phase3 MIGRATION_PLAN.csv的W2分配器plugins目标被本决定逐项替代；原文件原字节保留，SHA256 `7f7930414a5f0c858226f944815b64810aa760fad9f178ed29c4e10c6598d38c`。Phase1矩阵、旧架构报告和DEV映射中的冲突候选只保留历史证据效力，不能与本执行单并列作为另一条实施路径。W1以已完成C2版本化执行单为准；其他未来波次仍需各自Gate，不由本决定扩大授权。

优先级：用户明确授权范围 → 本ADR和W2执行单v1 → 同阶段审批请求 → 历史矩阵参考。执行前如出现新HEAD或新计划，先重新核对并版本化，不覆盖旧矩阵。
