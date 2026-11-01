# 目录整理后的v0.5数值验证

> 文档类型：证据。

- 为确认入口和文档移动未改变v0.5数值，在repo-structure上进行分支级验证。
- 验证源码HEAD：f2f96d5144750de11ea5527e114365793f4e484e；main与v0.5.0标签均为3fc46c0。
- 基准目录：results/allocation_comparison_v050_comparison_3seeds。
- 新目录：results/allocation_comparison_structure_validation，未覆盖已有输出。
- 正式60/60完成，失败0、未运行0；复用60条，其中reuse_from 60条，新跑0条。
- M0/M2b×ideal/lite四组全部rankable。
- summary仅排除simulation_elapsed_s，其余全部字段按原精度一致。
- comparability、effect_sizes、pareto、status逐行逐项一致，完成计数一致。
- MATLAB isequaln与CSV原始字段字符串双重核对，无容差、排序或四舍五入；differences.csv为0行。
- 旧14/14、平台6/6、六组冻结日志/PWM基线、比较器及PX4导出测试通过。
- 四个旧入口分别解析到apps/legacy和apps，文档链接断链0。
- 物理偏置新鲜复测仍在0.05°/s原断言下预期失败，独立进程按预期退出1，状态为expected_failure。
- 源码规范化Git对象及数值引擎与基准一致；已有CRLF/LF表示差异另列source_and_csv_audit.json，未改写源码。
- 结论：结构整理未改变v0.5数值；A段全部通过，允许随后仅本地ff合并，不移动标签、不push。
- [总记录](release_checks.json) · [逐项差异](differences.csv) · [源码与原始CSV审计](source_and_csv_audit.json)。
