# 名义效能与物理对象

[effectiveness_registry](effectiveness_registry.m)显式把`shc09_6dof`和`hover_linear`映射到工厂。工厂只包装原`ca_model`的名义部分，绝不重算真实气流舵效。

| 字段 | 单位/作用 |
|---|---|
| B / acceleration_matrix | 3×6，舵角rad到角加速度rad/s² |
| command_lower/upper | 六舵面候选命令rad边界 |
| trim_delta_rad | 公共配平初态；SHC09静止反扭矩补偿所需 |
| tau_model_s | 名义一阶执行器时间常数，不是真实或缓变tau |
| torque_matrix / inertia | 固定名义C和J，保留DCA原物理力矩二范数目标；不以J*B重新计算以免改变舍入 |
| plant_model | 工厂选择标识 |

真实执行器由[drivers/actuators](../drivers/actuators)推进，真实气动由[models/shc09](../models/shc09)计算。插件不收到`model.parameters`、实时出口速度、实际矩阵、vane_gain、扰动或传感器偏置。限幅、配平和名义tau由所有方法共用，不能解释为实机已识别参数。

## 添加飞行器

1. 在单独子目录编写返回上述名义字段的工厂，以唯一函数名前缀避免同名。
2. 在`effectiveness_registry.m`增加一项，并在模型/配置层提供明确plant_model标识。
3. 验证B的行满秩、维度、界和配平；添加独立物理测试与插件一致性检查。新物理对象属于后续任务，本轮只注册原有两种。

添加飞行器与添加分配算法是两个独立扩展点；本轮插件清单仍声明3维虚拟输入、6舵面，不能直接宣称支持任意维度。
