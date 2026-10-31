# WLS：增量加权最小二乘

> 文档类型：参考。

围绕delta_hat求增量，使归一化通道加权误差与输入偏好折中；保留原活动集求解器。

## 接口与实现

`wls_manifest()`声明清单，`[command,info]=wls_allocate(ctx)`调用[ca_wls.m](ca_wls.m)。五个研究算法源文件冻结，仅移动位置并包装；example_pinv为新增独立实现。

输入：`ctx.demand.v_h/v_c`为3×1角加速度需求；`state.delta_hat`为6×1名义舵角估计；`model`为固定名义B/J/C、界、配平与tau视图；`timing`为公共PWM时序；`config`经未修改的白名单截取。输出`command`为6×1 rad候选命令，实际舵机仍由共同PWM/限速动态执行。

配置：wls_axis_weights、wls_gamma、wls_input_weight、max_iterations

状态：active_set及原求解诊断，另有allocated_effect、iterations、exitflag、mode。 完整info原样进入topic日志。`solve_time_s`在调度层记录，与物理延迟无关。

## 假设与限制

全局默认[1000,1000,1]，第二轮主协议显式[1,1,1000]；权重选择会改变排序，不可混用。没有响应预测。

禁止访问真实舵效、气流、tau、扰动和传感器偏置。接口不是防恶意代码沙箱，插件作者应遵守契约。

## 来源与验证

Smeur等IMAV 2017增量WLS，第3节，来源与SHC09删除推力通道适配见[算法适配](../../docs/reference/method_adaptations.md)。

从仓库根目录运行：

```matlab
ca_setup;
test_plugin_conformance;
o=shc09_airframe();
r=main("WLS",o);
```

五种原方法还由`test_platform_baseline`与旧14项测试验证；example_pinv是第六项注册，不增加核心方法分支。[契约总览](../README.md) · [完整指南](../../docs/guides/platform_plugin_guide.md)。
