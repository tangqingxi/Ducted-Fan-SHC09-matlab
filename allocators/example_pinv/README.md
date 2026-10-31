# EXAMPLE_PINV：独立接口示例

> 文档类型：参考。

对总需求求pinv(B)最小范数解，然后逐元素限制到共同舵角边界。

## 接口与实现

`example_pinv_manifest()`声明清单，`[command,info]=example_pinv_allocate(ctx)`调用[example_pinv_allocate.m](example_pinv_allocate.m)。五个研究算法源文件冻结，仅移动位置并包装；example_pinv为新增独立实现。

输入：`ctx.demand.v_h/v_c`为3×1角加速度需求；`state.delta_hat`为6×1名义舵角估计；`model`为固定名义B/J/C、界、配平与tau视图；`timing`为公共PWM时序；`config`经未修改的白名单截取。输出`command`为6×1 rad候选命令，实际舵机仍由共同PWM/限速动态执行。

配置：使用model.B与command_lower/upper；无专属调参项。

状态：allocated_effect、iterations=1、exitflag=1、mode=0；公共兼容层另加旧日志字段。 完整info原样进入topic日志。`solve_time_s`在调度层记录，与物理延迟无关。

## 假设与限制

不优化动态、不分层；裁剪后不保持目标方向，不能把exitflag=1解释为满足原需求。

禁止访问真实舵效、气流、tau、扰动和传感器偏置。接口不是防恶意代码沙箱，插件作者应遵守契约。

## 来源与验证

基础Moore–Penrose伪逆示例；不是另一个已发表控制分配方法的完整复现。

从仓库根目录运行：

```matlab
ca_setup;
test_plugin_conformance;
o=shc09_airframe();
r=main("EXAMPLE_PINV",o);
```

五种原方法还由`test_platform_baseline`与旧14项测试验证；example_pinv是第六项注册，不增加核心方法分支。[契约总览](../README.md) · [完整指南](../../docs/guides/platform_plugin_guide.md)。
