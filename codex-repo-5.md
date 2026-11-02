# PINDI优先级拆分修正与验证停点报告

日期：2026-11-02，Asia/Shanghai。当前分支：`controller-ppid-p-indi`。

**结论：两行修正已完成，但测试没有全过；不建议进入正式批。** 本轮将用户要求的“测试必须全过”作为进入后续s201飞行回归及饱和探索的门槛，因此在Phase 1失败诊断后停止。没有修改测试或基线来放行，没有启动Phase 2的s201回归、Phase 3的完整F8伪逆飞行或Phase 4的load 0.78五方法探索，更没有重跑15条正式批。后续阶段尚未验证，不能写成已完成。

## 1. 控制路径与本轮范围

指定文件及指定旧SHA准确对应旧平台路径：

`platform/modules/rate_control/ca_indi_rate_control.m`

旧F8的s201日志由这条路径生成，使用lite估计器和800 Hz公共仿真。其参考角加速度此前确实归在高优先级项。新四环研究的`research/ppid_pindi/ppid_control_step.m`是另一条路径，已经使用“trim归nu_h，参考角加速度＋比例反馈归nu_c”的拆分，本轮没有修改它。不能把旧s201和新研究401–403的结果混作同一批。

生产数值源码只修改指定文件的两行：

```matlab
v_h=model.acceleration_matrix*feedback_delta-alpha; % 论文高优先级项只含配平与动态补偿。
v_c=alpha_reference+cfg.rate_gain(:).*(omega_reference-omega); % 参考角加速度与跟踪反馈归入低优先级项。
```

没有改分配器、Kp/Kv/Kq/Kω、参考、限幅、估计器或原协议JSON。诊断脚本、日志与证据均在新目录`results/pindi_split_audit_20261102_r1/`，不进入既有15条结果目录。

## 2. Phase 0/1：SHA、引擎与精确差异

| 项目 | 修改前 | 修改后 |
|---|---|---|
| 速率环文件SHA256 | `2a5eb7b3d6d7b981af3b45a7413ffe300f101952800ab2490f0f123959da9a39` | `45def4d44c397a10e6aa538191955da8952fe837f2ae947377b889338517352f` |
| 数值引擎指纹 | `ad9f910438cd71da2fdcc2f18c3553cc1e4b47d9b90287ef7200a032f201ef17` | `86a39d2241d3d7b6c5d6814b7149e1ceb1f812aab530889f73efd09336ba8ec9` |

引擎包含该速率环文件，因而指纹变化是预期结果。与本轮Phase 0逐文件快照比较，只有这一个已有Git跟踪文件内容改变，`git diff --numstat`为2行增加、2行删除。精确unified diff及old/new SHA见`phase1_change.json`，修改前文件副本见`ca_indi_rate_control.before.m`。

没有重写旧冻结锁，也没有把旧结果的引擎指纹改成新值。新四环研究的`formal_lock.json`仍保留原来的历史来源；由于公共引擎改变，当前源码与该锁的引擎项不再一致，现有正式入口应拒绝直接追加运行。这不等于旧结果被改写，也不应通过更新旧锁绕过检查。

## 3. 两个测试套件与冻结基线

实际执行结果：

| 检查 | 结果 | 失败/通过位置 |
|---|---|---|
| `run_project_tests(false)` | **未通过** | 首项`test_shc09_physics`通过；第二项`test_comparison`第117行失败：两种PCA未复现原指令。后续12项因套件中止未执行，不计为通过。 |
| `run_platform_tests` | **6/6通过** | bus、scheduler、params、plugin_conformance、topic_chain、topic_logger全部通过。 |
| `test_platform_baseline` | **未通过** | 首个案例`M0_20s_DA_NS`的`position_ned_m`逐位SHA不同；后续案例没有执行。 |

原始日志为`phase1_tests.log`，结构化结果为`phase1_tests.json`。没有修改`test_comparison.m`、`test_platform_baseline.m`或`tests/baseline/numeric_baseline.mat`。

### 3.1 基线失败：逐位冻结与浮点重组

对首个M0基线进行额外诊断重放，比较基线文件保存的稀疏样本：

| 字段 | 稀疏样本最大绝对差 | 单位 |
|---|---:|---|
| 位置 | 9.5749e−16 | m |
| 欧拉姿态 | 1.5714e−15 | rad |
| 舵面命令 | 7.6605e−15 | rad |
| 实际舵角 | 6.2728e−15 | rad |
| 测量角速度 | 1.5327e−14 | rad/s |
| 测量角加速度 | 3.1442e−13 | rad/s² |
| v_h、v_c各自 | 约2.9375 | rad/s² |

最后一行是预期的分项搬移，不能把它解释为实际位置/姿态发生2.9375量级变化。以上是基线保存的稀疏样本差，不冒充原、新完整状态轨迹的最大差。

在这次重放的同一组反馈状态上，独立重建原、新算式：

```text
原总需求 = (trim + alpha_reference) + feedback
新总需求 = trim + (alpha_reference + feedback)
```

两者最大差为**1.4211e−14 rad/s²**。按矩阵批处理方式重建新公式与逐拍日志总需求的最大差为**2.8422e−14 rad/s²**。结果支持“总需求代数不变，机器浮点重组造成末位差异”的解释；逐位SHA要求仍会因此失败，不能在报告中把失败改称通过。

这些证据来自M0失败诊断，不代替用户要求的F8 s201完整轨迹回归；后者尚未执行。数据见`baseline_sparse_differences.csv`和`phase1_diagnosis.json`。

### 3.2 项目测试失败：旧拆分兼容契约已不适用

`test_comparison`后半段与`tests/legacy_reference`中的旧实现比较，要求PCA命令误差小于1e−9 rad、姿态误差小于1e−10 rad。该旧实现保留旧优先级拆分。

按原测试第一个PWM相位0的0.2 s姿态案例，补充诊断两种PCA：

| 方法 | 新旧舵面命令最大差 rad | 新旧欧拉姿态最大差 rad |
|---|---:|---:|
| PCA_STATIC | 约0.94952 | 约0.0020238 |
| PCA_PREDICTIVE | 约0.68830 | 约0.0013743 |

这是受限PCA在拆分改变后的实际行为变化，不能归为1e−14浮点误差。总需求在同一输入上相同，不保证受限PCA结果相同，因为PCA本来就分别处理高、低优先级需求。这一旧行为完全复现契约与本次修正发生冲突，不能单靠放宽数值容差解决。

诊断没有重写或删除旧实现；两份小型日志分别保存为`legacy_compatibility_PCA_STATIC.mat`、`legacy_compatibility_PCA_PREDICTIVE.mat`，比较表为`legacy_compatibility_differences.csv`。

### 3.3 旧s201同输入需求比例核对：未重飞

只读取旧DA_NS s201日志，将`alpha_reference`从原v_h移到v_c，按主窗峰值除以名义纯偏航容量计算：

| 项目 | 数值 |
|---|---:|
| 名义纯偏航容量，约束横滚/俯仰效果为0 | 103.7555 rad/s² |
| 原v_c偏航峰值 | 3.5630 rad/s²，容量的3.4340% |
| 重分组后v_c偏航峰值 | 24.7673 rad/s²，容量的23.8708% |
| 同输入总需求最大差 | 1.2434e−14 rad/s² |

这支持参考角加速度应归入跟踪项的修正方向，并与“约24%”相符。在本次明确定义的DA_NS s201口径下，旧值为3.43%，不把背景中的“约2%”追认为实测值。证据为`same_input_s201_split_audit.json`。这是旧轨迹上的公式重分组，不是新闭环轨迹回归，也不能据此断言饱和时PCA跟踪或舵面代价的变化。

## 4. Phase 2/3/4执行状态

| 要求 | 本轮状态 |
|---|---|
| DA_NS s201与旧52 s F8日志回归 | **未执行**：Phase 1未全通过。不能报告为1e−10一致。 |
| PCA_PREDICTIVE s201回归 | **未执行**：跟踪、PWM步变和行程变化未知。 |
| EXAMPLE_PINV s201完整F8对照 | **未执行**。平台插件测试中的0.2 s伪逆调用不计作此项。 |
| 论文增益核对 | **已完成，只读，不改参数**，见下一节。 |
| 参考/模型/完整cfg保持不变 | **已完成**：重新构造s201后，与Phase 0保存的c、m、ref逐项`isequaln`一致。 |
| load 0.78、五方法×一seed饱和预研 | **未执行**。没有生成新饱和数据，也没有将旧load 0.6结果冒充新预研。 |
| 正式15条批次、v3协议或301–303种子运行 | **未执行，未批准进入**。 |

因此，本报告没有新的lambda占空比、最长episode、PWM缩放事件数或load 0.78跟踪/执行器结果。它们是尚未执行的待验证项，不能填0或写“lambda仍为1”。当前也不能下“load 0.78无法验证该改动”的结论。

## 5. 外围参数与论文表1

来源为用户提供的`C:/Users/32450/Desktop/GNC/book/ws-gnc.pdf`第6页，已抽取文本并检查页面图。表1是对角增益，按三个轴列出：

| 参数 | 论文表1 | 本轮修改的旧F8路径 | 新四环研究路径，未修改 | 结论 |
|---|---|---|---|---|
| Kp | [1.30,1.30,1.00] | position_gain=[1.3,1.3,1] | position_gain=[1.3,1.3,1] | 一致 |
| Kv | [3.20,3.20,2.10] | velocity_gain=[3.2,3.2,2.1] | velocity_p=[3.2,3.2,2.1] | 比例项一致；新协议没有名为velocity_gain的字段 |
| Kq | [5.00,5.00,4.00] | attitude_gain=[8,8,8] | attitude_gain=[6,6,6] | 两条实现均与论文不同；均未改 |
| Kω | [9.20,9.20,7.40] | rate_gain=[12,12,12] | rate_gain=[12,12,12] | 不一致，未改 |

旧F8所用协议包括`configs/f8_protocol_v1.json`及每条日志的protocol；新四环协议为`research/ppid_pindi/protocol.json`，不能把其中的Kq=6写成8。论文另列的PID积分/微分项不表示本文旧F8速率环使用PID，本次没有替换控制结构。

外围完整性检查见`configuration_integrity.json`：

- 重新构造的完整cfg、名义模型和参考与修改前逐项完全相同。
- 旧F8仍为lite、800 Hz公共仿真；新四环的ECL/400 Hz方案未改。
- 增益、舵角/舵速限制、推力/倾角上限、参考及传感器配置没有改动。

## 6. 历史结果、源码与Git保护

本轮前后逐文件SHA、字节数及文件集合核验覆盖两套15条结果目录，共**133个文件，全部不变**：

1. 原工作区旧确认批：`E:/Ducted-Fan-SHC09-matlab/results/f8_pressure_confirm_20261101_Rbase_v2_holdout_3seeds_rerun1/F8PR-Y60-F075/`。
2. 新工作树的四环正式批：`results/ppid_pindi_formal_20261101_locked_v11/`。

新四环来源锁显式列出的49个文件也全部保持原SHA；只有其公共引擎所覆盖的本次授权文件改变。`final_integrity.json`保存核验结果。原始MAT没有写入或覆盖，结果目录没有新增文件，基线文件没有改动。

`git diff --check`通过；索引为空。main仍为`9918d9dba180f38a62c36f602e37993b87d0d38d`，f8-research与当前HEAD仍为`7c5c9ab91fdb310c33d5bf08209e0302e540008f`。没有提交、打tag、push、合并、重置或清理其他工作区修改。

## 7. 是否建议进入正式批

**不建议。** 当前既未满足用户要求的测试全通过条件，也没有完成s201总需求完整轨迹回归、伪逆对照及load 0.78激励确认。不能据此追认正式协议v3或启动15条。

需要用户先决定旧测试契约如何迁移，才能继续：

1. 将旧拆分的兼容性回归与新拆分的正确性测试明确分开。保留旧实现作历史证据，增加非零参考角加速度下的两项公式及总需求守恒检查；不要把旧受限PCA指令差异当作浮点误差放宽。
2. 冻结数值基线采用逐位一致，预期会因浮点重组及v_h/v_c日志语义改变而失效。是否建立新版本基线或另设有界差异回归，须由用户批准；本轮不修改基线，也不自行认定为通过。
3. 测试契约解决后，再依次完成原计划Phase 2、Phase 3伪逆飞行和Phase 4单种子探索。只有探索实际产生有效缩放并满足名义几何检查，才提出新正式协议供批准。

本轮保留两行修正及全部失败证据，停在这里等待下一步决定。
