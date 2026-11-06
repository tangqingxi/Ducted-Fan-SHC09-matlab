# 从零写一个控制分配插件

> 文档类型：当前。

目标：新增一个目录和一项显式注册，平台控制链不按方法名分支。仓库不使用MATLAB +package目录，因此实现文件有唯一前缀；清单和allocator是角色名称，不要求多个插件都定义同名manifest.m。

## 1. 了解上下文

| ctx分组 | 内容 | 单位/边界 |
|---|---|---|
| demand | v_h补偿、v_c跟踪 | 3×1 rad/s² |
| state | delta_hat | 6×1 rad名义估计，非真舵角 |
| model | B/acceleration_matrix、torque_matrix、inertia、command_lower/upper、trim_delta_rad、tau_model_s、plant_model | 固定名义视图，见[effectiveness](../../effectiveness/README.md) |
| timing | delay_s、hold_s、horizon_s、delivery_time_s、held_command等原PWM信息 | 秒、rad；只公开名义时序 |
| config | ca_allocator_config原白名单 | 名义tau、限速、求解器及各方法参数；无真值 |

J/C是DCA原物理力矩目标必须的固定度量；不从真实流场更新，也不通过J*B重新计算而改变舍入。不得把完整cfg或model.parameters传进插件。插件也不得自行调用plant/sensor、读取文件真值、读写全局或改变随机流。

## 2. 最小示例

下面的allocator为20行最小示例，另附清单，可保存为`allocators/example_pinv`下的对应文件。仓库已有此示例，复用时请换唯一前缀/名称。

```matlab
function m = example_pinv_manifest()
% 声明名称、输入需求、通用状态和能力。
m=allocator_manifest("EXAMPLE_PINV", ...
    ["demand.v_h","demand.v_c","model.B"],false);
end
```

```matlab
function [command,info] = example_pinv_allocate(ctx)
% 只使用当前需求和名义效能。
v_h=ctx.demand.v_h;
v_c=ctx.demand.v_c;
B=ctx.model.B;
% 不读取未来参考或物理对象。
target=v_h+v_c;
command=pinv(B)*target;
% 每个舵面使用共同公开边界。
lower=ctx.model.command_lower;
upper=ctx.model.command_upper;
command=min(max(command,lower),upper);
% 裁剪后效果可能偏离原需求。
info=struct();
info.allocated_effect=B*command;
info.iterations=1;
info.exitflag=1;
% 此示例不提供优先级模式。
info.mode=0;
end
```

它是接口示例，逐元素裁剪不保方向；exitflag=1只表示示例计算完成，不证明目标可达。

## 3. 注册

在[registry.m](../../allocators/registry.m)数组增加一项（example_pinv已存在，不重复加）：

```matlab
entry('EXAMPLE_PINV','example_pinv',@example_pinv_allocate,@example_pinv_manifest)
```

`entry`是registry内部辅助函数；此行应置于数组中，不是在命令窗口单独运行。`ca_setup`遍历显式注册目录加入路径，既不自动扫描也不修改核心。旧编号1～5保持固定；新增方法使用字符串名称。

## 4. 清单与调度

清单至少包含name、version、requires、info_fields、supports、max_solve_time_s。requires为点分字段路径；dispatch检查ctx字段存在。supports声明6舵面/3维、需求分层能力和确定性。通用info_fields为allocated_effect、iterations、exitflag、mode；算法专属lambda/beta/restore等自由追加。

`allocator_info`在五个原包装中只补齐旧入口默认值，保证不改原函数。调度器校验命令有限性与6×1维度，兼容入口检查公共边界并完成原预测/残差后处理。`max_solve_time_s`是信息性预算，不是实时保证、不触发隐藏延迟或降级。

新的topic状态是`struct('allocator',name,'info',info)`；logger原样保存，不识别算法种类。`src/compat/ca_complete_allocation`和sim复制旧专属列仅为历史分析，不让新平台逻辑依赖它们。

## 5. 测试和运行

```matlab
ca_setup;
test_plugin_conformance;
r=main("EXAMPLE_PINV",shc09_airframe());
```

一致性测试遍历所有注册插件和四组冻结需求，检查清单、有限/限幅、原生重复输出确定性、通用info和递归真值隔离，毒化真实参数后ctx应不变；另用旧main做示例集成。改变原五方法的包装后，还需运行`run_project_tests(false); test_platform_baseline;`；新算法自身正确性需额外独立证明，不能只依赖接口测试。

## 6. 增加模型与可信范围

新飞行器在独立effectiveness注册点增加，不能在某算法中偷偷重建实际B。新增传感器/导航应通过测量topic，不传真实状态。MATLAB函数路径并不阻止恶意插件读取任意文件，因此这里验证的是正常工程接口与确定性契约，不是安全隔离沙箱。

[平台](../../platform/README.md) · [所有插件](../../allocators/README.md) · [PX4职责映射](platform_px4_mapping.md)。
