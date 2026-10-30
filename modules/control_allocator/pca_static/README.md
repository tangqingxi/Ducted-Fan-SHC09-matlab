# 原静态PCA

已接入`ca_pca_static.m`，方法标识为`PCA_STATIC`。共享核心在`../pca_predictive/ca_priority_core.m`，静态模式使用原B矩阵和静态舵角边界。

正常LP对应论文式29，补偿回退对应式30；`ca_restore.m`用零空间投影公式等价实现Algorithm 1的增广矩阵恢复步骤。数值容差与兜底扩展见`../../../docs/static_pca_algorithm_audit.md`。

`ca_dp_lpca.m`、`ca_simplex.m`和`ca_restore.m`保留原仓库独立副本，来源清单见`../../../docs/copy_manifest.json`。当总需求可达、lambda=1且伪逆解满足边界时，恢复结果与伪逆相同属于预期行为。
