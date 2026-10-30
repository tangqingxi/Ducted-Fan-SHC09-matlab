# PCA_PREDICTIVE：响应预测补偿优先分配

先预测旧命令等待段，再预测新命令完整保持段，使用保守非限速仿射界做补偿优先LP；默认以保持第一阶段效果为约束，最小化相对已保持命令的距离。

## 接口与实现

`pca_predictive_manifest()`声明清单，`[command,info]=pca_predictive_allocate(ctx)`调用[ca_pca_predictive.m](ca_pca_predictive.m)。五个研究算法源文件冻结，仅移动位置并包装；example_pinv为新增独立实现。

输入：`ctx.demand.v_h/v_c`为3×1角加速度需求；`state.delta_hat`为6×1名义舵角估计；`model`为固定名义B/J/C、界、配平与tau视图；`timing`为公共PWM时序；`config`经未修改的白名单截取。输出`command`为6×1 rad候选命令，实际舵机仍由共同PWM/限速动态执行。

配置：tau_model_s、rate_limit_deg_s、predictive_horizon_fraction、predictive_restore_mode、constraint_tolerance、max_iterations。

状态：lambda/beta、mode、native_predicted_delta、prediction_*、restore_*、equality_error及通用字段；exitflag沿用旧入口默认。 完整info原样进入topic日志。`solve_time_s`在调度层记录，与物理延迟无关。

## 假设与限制

minimum_change为既有默认；legacy_norm保持旧绝对范数恢复。历史目标不改变第一阶段优先级。依赖名义动态，不提供一般闭环稳定性或实机优势证明。

禁止访问真实舵效、气流、tau、扰动和传感器偏置。接口不是防恶意代码沙箱，插件作者应遵守契约。

## 来源与验证

PCA适配见[算法说明](../../docs/method_adaptations.md)；历史输入次级目标借鉴O. Härkegård, JGCD 27(6), 1028–1034, 2004, DOI 10.2514/1.11607，不是整篇算法复现。

从仓库根目录运行：

```matlab
ca_setup;
test_plugin_conformance;
o=shc09_airframe();
r=main("PCA_PREDICTIVE",o);
```

五种原方法还由`test_platform_baseline`与旧14项测试验证；example_pinv是第六项注册，不增加核心方法分支。[契约总览](../README.md) · [完整指南](../../docs/platform_plugin_guide.md)。
