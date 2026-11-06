# 55秒起飞型正式批轻量证据

[完整报告](../../../docs/history/ENGINEERING_HISTORY.md) · [正式图表](../../../figures/hover_distance_takeoff_formal_20261103_r1/README.md) · [单飞行容器清单](../../../logs/wtr/hover_distance_takeoff_formal_20261103_r1/README.md)

先决PCA_PREDICTIVE／501预检1条通过，再五方法×501/502/503正式15条，每条55秒。formal_protocol、sources、source_lock、formal_lock为本批实际执行版本的原字节副本。重型MAT及预生成输入留在results/hover_distance_takeoff_formal_20261103_r1，不纳入本轻量包。

status／metrics／provenance／completion逐字节复制本次新批记录；independent_checks为15条源MAT／.wtr及指标独立复核结果。precheck_formal_501_bitwise证明先决预检与正式501预测PCA的13个关键数组原始字节一致，没有增加仿真调用。

protected_before／after记录712个旧源码、锁及保留交付文件SHA前后一致；execution_sources_verified记录全部16次飞行结束时70个显式源文件及ECL二进制与飞前冻结记录一致。engine是共同数值引擎摘要，不含research，必须同时看显式文件SHA。

## 汇总中断与独立续跑

首条DA_NS已完整保存并导出.wtr，原驱动在空结构体累加器赋值时报错。summary_recovery_exception记录原错误、1条已完成＋14条not_run、原锁与原驱动SHA。独立hdtfr_resume只补14条未运行项；无成功项重飞、无参数／门槛变化。原运行日志保留在本批work及根hdtf／hdtfr_execution日志，不将此管理中断冒充飞行失败或无中断运行。

## 当前代码与本批执行版本不同之处

全部飞行完成且核对来源后，hdtf_run的管理逻辑作两处修复：用pre_metrics([])建立同字段空累加器；把缺失error_id规范化为空字符串。没有改控制／对象／参考／分配器／门禁，没有再仿真，旧锁不更新。

- hdtf_run.frozen.m保存本批使用的原始驱动字节，仅供核对，不应将此文档目录加入MATLAB路径。
- post_batch_management_fix.patch／json含精确diff、old/new SHA及修复时点。
- management_check.m／json只测试结构体累加、状态字符串和解析，并重算共同引擎，不调用对象仿真。两次初始调用存在引号／脚本路径入口错误，修正入口后检查通过，未触发新飞行。
- 当前源hdtf_run仅供未来另立新tag时使用；本批历史来源仍是frozen版本＋独立续跑驱动，不静默改写锁中的SHA。

## 回放和绘图

replay_summary记录打包WindTrace.exe在6／14／21／32／52秒五阶段离屏3D检查；playback_live是源码UI真实Qt计时推进约2秒，无桌面控制。末段保持高度，无降落模型。

plot_review保存首次λ图和清单，correction.json记录仅增加mode2工程兜底标记的图审修正；没有改指标或飞行数据。正式图中的λ正常值保留NaN空缺，mode1／mode2用不同符号表达。

manifest.json列出本包文件bytes和SHA。没有原始MAT、完整tracks／geometry、多方法bundle或运行包副本；不提交、不push。
