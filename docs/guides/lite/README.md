# 理解 ideal/lite：建议阅读顺序

> 文档类型：当前。

ideal 使用真值作为理想参考；lite 从原始传感器测量估计姿态、角速度、位置和速度。lite 仍是实验候选，当前 M0/M2b 可比较不等于物理偏置验收已通过。

1. 先看[修复说明](fix.md)：了解 GNSS 修正连续注入、CSV 空列修复、验证和仍存在的限制。
2. 想知道为什么改，再看[修复前一页诊断](peak_diagnosis.md)：定位原主窗峰值及其触发链。
3. 想比较方法，看[结果与种子波动](results.md)：区分“具备比较资格”和“方法差异超过波动”。

[完整比较指南](../allocation_comparison_guide.md)定义门禁和读表方式；[v0.5 发布说明](../../releases/release_notes_v0.5.0.md)记录发布范围；[Stage5/6A 历史](../../history/README.md)只提供背景，不改写成当前依赖。

lite 的物理偏置仍按 0.05°/s 门限评价且预期失败。默认 ideal，不用真值给 lite 兜底，不因文档移动而重跑研究。
