# 估计反馈分配比较 MVP

从根目录执行一次入口即可得到五方法的分窗指标与二维 Pareto：

```matlab
ca_setup;
s = estimated_allocation_comparison_app;
s = estimated_allocation_comparison_app('mode','lite','experiments','both','seeds',1,'use_cached',true,'output_tag','my_study');
```

输出为 `results/estimated_comparison_<tag>/summary.csv`、`pareto.csv`、`metric_effects.csv`、`provenance.csv`、`report.md` 和六张 `figures/pareto_*.png`。禁止覆盖已有输出。模式：ideal=oracle、lite=experimental（入口默认，平台默认仍 ideal）、px4_ecl=归档 ECL 独立交叉验证，需 JVM。旧 `estimator_comparison_app` 调用不变。

`experiments` 接受 E1、E2、both 或字符串数组；`seeds` 为正整数标识数组，各随机流种子按 seed−1 同步递增。五方法保持相同配置、参考、物理初态和预生成噪声，仅换分配器；传感器测量随各自闭环物理轨迹变化。

优先读取 Stage 6A 的 seed=1 数值日志（ideal/lite 在 results/estimator_diagnosis/metrics，ECL 在 ECL 子目录），其次读取本入口 results/estimated_comparison_cache 缓存。配置和参考必须完全一致，否则停止。缺失时仅补当前 mode/实验/种子的缺失方法，不隐式运行其他模式或四十次旧设计。use_cached=false 明确重跑所选子集。缓存没有 topic 历史时据实记录 unavailable_numeric_cache，不伪称重新验证隔离；新仿真对非理想模式直接检查三个真值 topic 缺席，保存独立审计标记，失败停止且不 fallback。

| 实验 | whole | task | transient |
|---|---|---|---|
| E1 | 0–12 s | 2–10 s | 0–2 s |
| E2 | 0–20 s | 6–16 s | 0–6 s |

E2 whole 显示早期响应收益，task 检查稳态是否被估计误差淹没。窗口预先固定，不按排名挑选；两秒 smoke_test=true 仅供契约测试，窗口另为 [0,2]/[1,2]/[0,1]，不替代研究协议。

指标直接复用 [逐日志指标](../analysis/estimator_feedback_metrics_row.m)：姿态/偏航/位置/角速度真值误差只用于离线评价；allocation demand error 和 common_residual 的单位是 rad/s²，乘名义惯量 J 后另报 Nm。共同残差按所有方法相同的执行器预测终点计算。native residual 对应原生动态目标，不跨目标强行排名。PWM 步变、总变差与饱和是控制代价；mode1/2 对非 PCA 不适用。估计误差列记录姿态、位置及最大轴偏置 RMS/末值。

Pareto 表分别最小化三个横轴代价（PWM 步变、总变差、饱和）与三个纵轴误差（主跟踪指标、角速度、共同预测力矩），共九种二维权衡。黑圈为该指标对的非支配点，数值比较逐轴容差 1e−9×max(1,绝对值)。点位置是当前种子均值，不能当成显著性或全局最优；同坐标方法允许重合，图例及表给出五方法标签，静态 PCA、DCA、预测 PCA 各自保留。

metric_effects 给出方法均值极差/方法内池化种子标准差。当前多种子数据优先；单种子的标准 E1/lite whole 可引用原三种子汇总，并明确历史来源；其他单种子留缺失。姿态/偏航差异小于种子波动写“不可分辨”，波动未知也不能排名。没有综合分数，Pareto 的数值边界不代表统计上可区分。

结论边界：lite 物理偏置 .05°/s 门禁仍未过，未调 kp/ki；ECL 旧版、噪声谱/游走/滤波路径与 lite 不同；真实与名义 tau 仍匹配，预测残差接近零可能来自匹配模型。单种子或三种子只报告方向和效应量，不宣称某方法全局最优、实机优势、任意估计噪声下排序相同。

## Phase A 验收

运行 `ca_setup; test_estimated_allocation_comparison;` 做新鲜两秒五方法隔离、输出和缓存确定性检查；随后完整 `run_project_tests; run_platform_tests; test_platform_baseline;`。完整 E1/E2 缓存示例及 PNG 另做目视核验。Stage 5/6A 的失败状态与旧报告结论不修改。

实际验收：新鲜烟雾及缓存重放、已知 Pareto 支配/平局/无效点测试通过；正式 lite E1/E2 十份输入全部命中缓存，三十行汇总、二百七十行 Pareto、六图齐全；ideal/ECL 可选缓存入口通过。14 旧测试、6 平台测试、六组逐位基线通过；run_estimator_tests 仍在 LitePhysicalBias 失败。[验收记录](estimated_comparison_validation/mvp_checks.json) · [版本化轻量示例](../examples/estimated_comparison/README.md)。
