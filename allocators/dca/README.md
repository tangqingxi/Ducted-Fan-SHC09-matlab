# DCA：动态终点可达分配

> 文档类型：参考。

用完整限速一阶模型映射终点可达区间，优化物理力矩二范数误差，再二分反解舵命令。

## 接口与实现

`dca_manifest()`声明清单，`[command,info]=dca_allocate(ctx)`调用[ca_dca.m](ca_dca.m)。五个研究算法源文件冻结，仅移动位置并包装；example_pinv为新增独立实现。

输入：`ctx.demand.v_h/v_c`为3×1角加速度需求；`state.delta_hat`为6×1名义舵角估计；`model`为固定名义B/J/C、界、配平与tau视图；`timing`为公共PWM时序；`config`经未修改的白名单截取。输出`command`为6×1 rad候选命令，实际舵机仍由共同PWM/限速动态执行。

配置：tau_model_s、rate_limit_deg_s、dca_horizon_s、max_iterations；空horizon默认一个PWM周期。

状态：objective_torque_error、native_predicted_delta、native_horizon_s、native_prediction_available及通用字段。 完整info原样进入topic日志。`solve_time_s`在调度层记录，与物理延迟无关。

## 假设与限制

从当前估计偏角预测，不计PWM等待旧指令阶段；实际下发仍走共同PWM。固定名义C/J保留原目标，不读取实际气流或真实tau。

禁止访问真实舵效、气流、tau、扰动和传感器偏置。接口不是防恶意代码沙箱，插件作者应遵守契约。

## 来源与验证

Venkataraman等2004框架，单点终点离散化是本项目适配，并非完整长窗口MPC；见[算法适配](../../docs/reference/method_adaptations.md)。

从仓库根目录运行：

```matlab
ca_setup;
test_plugin_conformance;
o=shc09_airframe();
r=main("DCA",o);
```

五种原方法还由`test_platform_baseline`与旧14项测试验证；example_pinv是第六项注册，不增加核心方法分支。[契约总览](../README.md) · [完整指南](../../docs/guides/platform_plugin_guide.md)。
