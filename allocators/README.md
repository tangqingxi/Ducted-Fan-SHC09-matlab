# 分配器插件

平台只通过[registry](registry.m)读取name、目录、allocate/manifest句柄；不扫描目录。五个原算法源文件原字节搬迁，薄包装统一签名，第六个example_pinv验证接口通用。

| 插件 | 优化对象 | 补偿/跟踪分层 | 执行器假设 | 主要限制 |
|---|---|---|---|---|
| [DA_NS](da_ns/README.md) | 总需求方向与零空间修正 | 无 | 静态 | 对称界，数值退化缩放 |
| [WLS](wls/README.md) | 通道加权误差及输入偏好 | 通道权重，非需求分层 | 静态增量 | 排名高度依赖权重 |
| [DCA](dca/README.md) | 一步终点物理力矩误差 | 无 | 完整限速一阶可达区间 | 原生预测不计PWM等待 |
| [PCA_STATIC](pca_static/README.md) | 补偿优先LP与绝对输入范数 | 有 | 静态B和舵角界 | 无响应预测 |
| [PCA_PREDICTIVE](pca_predictive/README.md) | 预测终点优先LP与历史命令距离 | 有 | 等待+保持、保守仿射可行界 | 名义模型依赖、非一般MPC |
| [EXAMPLE_PINV](example_pinv/README.md) | 伪逆及逐元素裁剪 | 无 | 静态 | 边界不保方向，仅作示例 |

## 契约

入口`[command,info]=prefix_allocate(ctx)`返回6×1 rad命令和结构状态。ctx包含`demand.v_h/v_c`、`state.delta_hat`、`model`名义视图、PWM`timing`和`ca_allocator_config`白名单`config`。白名单即使在旧`ca_allocate`调用也强制执行。

清单`prefix_manifest()`至少含`name/version/requires/info_fields/supports/max_solve_time_s`。`supports`声明3维虚拟控制、6个舵面、优先需求能力和确定性。通用info字段为`allocated_effect/iterations/exitflag/mode`；`allocator_info`只补齐旧默认状态。专属信息保留在`control_allocator_status.info`，平台不按算法名解释。

`max_solve_time_s=1/800`是观测预算，不保证当前桌面计算满足800Hz，不导致物理等待或丢帧。实际`solve_time_s`单独记录，不参与数值基线。

原DCA的名义J/C属于保留目标所需固定度量，插件并未得到实际矩阵。禁止读取全局变量、plant/sensor、真值文件或真实配置；MATLAB目录/函数边界并非操作系统沙箱，遵守接口还需代码审查。

## 添加与验证

新增目录和两函数，再加registry一行；`ca_setup`自动加入显式注册的目录。没有`+package`，因此实现文件采用唯一前缀，而非多个同名`manifest.m/allocator.m`。详见[插件指南](../docs/platform_plugin_guide.md)。

根目录执行`ca_setup; test_plugin_conformance;`测试所有注册插件的冻结ctx、确定性、有限性、边界、清单和真值隔离，并用旧入口运行example_pinv。完整回归还需`run_project_tests(false); test_platform_baseline;`。
