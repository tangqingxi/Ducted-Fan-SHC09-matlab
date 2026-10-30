# PCA_STATIC：静态补偿优先分配

先保持补偿并最大化跟踪比例；补偿不可达时缩放补偿，再以静态效能不变约束做最小绝对输入范数恢复。

## 接口与实现

`pca_static_manifest()`声明清单，`[command,info]=pca_static_allocate(ctx)`调用[ca_pca_static.m](ca_pca_static.m)。五个研究算法源文件冻结，仅移动位置并包装；example_pinv为新增独立实现。

输入：`ctx.demand.v_h/v_c`为3×1角加速度需求；`state.delta_hat`为6×1名义舵角估计；`model`为固定名义B/J/C、界、配平与tau视图；`timing`为公共PWM时序；`config`经未修改的白名单截取。输出`command`为6×1 rad候选命令，实际舵机仍由共同PWM/限速动态执行。

配置：constraint_tolerance、max_iterations；静态恢复不随predictive_restore_mode切换。

状态：lambda、beta、mode、solver_rescue、restore_*、equality_error及通用字段；exitflag沿用旧入口默认。 完整info原样进入topic日志。`solve_time_s`在调度层记录，与物理延迟无关。

## 假设与限制

共享ca_priority_core的静态分支，原B和静态边界。可达域内与伪逆/其他方法重合是预期现象。

禁止访问真实舵效、气流、tau、扰动和传感器偏置。接口不是防恶意代码沙箱，插件作者应遵守契约。

## 来源与验证

论文Algorithm 1：式29正常LP、式30回退；ca_restore为等价零空间恢复。对应关系见[静态审计](../../docs/static_pca_algorithm_audit.md)与[适配](../../docs/method_adaptations.md)。

从仓库根目录运行：

```matlab
ca_setup;
test_plugin_conformance;
o=shc09_airframe();
r=main("PCA_STATIC",o);
```

五种原方法还由`test_platform_baseline`与旧14项测试验证；example_pinv是第六项注册，不增加核心方法分支。[契约总览](../README.md) · [完整指南](../../docs/platform_plugin_guide.md)。
