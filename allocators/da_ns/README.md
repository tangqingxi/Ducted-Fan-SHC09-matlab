# DA_NS：直接分配与零空间迭代

总需求v_h+v_c先做方向保持直接分配，随后伪逆/归一化零空间迭代；超限或退化时按原流程缩放。

## 接口与实现

`da_ns_manifest()`声明清单，`[command,info]=da_ns_allocate(ctx)`调用[ca_da_ns.m](ca_da_ns.m)。五个研究算法源文件冻结，仅移动位置并包装；example_pinv为新增独立实现。

输入：`ctx.demand.v_h/v_c`为3×1角加速度需求；`state.delta_hat`为6×1名义舵角估计；`model`为固定名义B/J/C、界、配平与tau视图；`timing`为公共PWM时序；`config`经未修改的白名单截取。输出`command`为6×1 rad候选命令，实际舵机仍由共同PWM/限速动态执行。

配置：max_iterations、constraint_tolerance

状态：direction_scale、iterations、exitflag、mode；其余通用状态由薄包装/兼容层补齐。 完整info原样进入topic日志。`solve_time_s`在调度层记录，与物理延迟无关。

## 假设与限制

静态B、对称舵角界；不预测实际执行器响应，不区分补偿与跟踪。

禁止访问真实舵效、气流、tau、扰动和传感器偏置。接口不是防恶意代码沙箱，插件作者应遵守契约。

## 来源与验证

CN109976368B，步骤与退化适配见[算法适配](../../docs/method_adaptations.md)。

从仓库根目录运行：

```matlab
ca_setup;
test_plugin_conformance;
o=shc09_airframe();
r=main("DA_NS",o);
```

五种原方法还由`test_platform_baseline`与旧14项测试验证；example_pinv是第六项注册，不增加核心方法分支。[契约总览](../README.md) · [完整指南](../../docs/platform_plugin_guide.md)。
