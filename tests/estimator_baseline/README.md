# Stage 5验收记录

起点d5cb2c4，tag estimator-realism-start。stage0_checks.mat记录14项旧测试、6项平台测试、20秒及五方法2秒逐位基线；五入口0.2秒通过。完整日志在本地archive/platform_refactor/estimator0_output.txt。禁止为通过检查修改冻结物理/算法或旧数值基线。


Stage1记录14+6和传感器检查，Stage2记录姿态收敛/隔离/12秒五方法烟雾及ideal基线，Stage3记录四项新测试和时间戳修正后基线。final_checks.mat包含最终14+6+4、JVM导航与基线，四份final_*.csv和final_details.json便于阅读。fault_isolation_checks.mat补查任务首帧NaN后停止与参数白名单；logger_export_checks.mat与navigation_metrics_checks.mat检查lite导出/ECL指标兼容；metadata_checks.mat是日志元数据修正后的ideal重放与隔离复查。

完整E1/E2数据见[轻量CSV](../../examples/estimator_realism/README.md)，过程与限制见[真实化报告](../../docs/estimator_realism_report.md)。完整本地执行记录在archive/estimator_realism和archive/platform_refactor，不随Git发布；没有为通过测试改动旧数值基线。


**总体未通过。** final_checks/final_details中的4项是追加真实物理闭环门禁之前的测试，不代表整个Stage5通过。physical_attitude_check.mat及physical_attitude_details.json保存追加真实物理轨迹结果，run_estimator_tests新增第五项物理门禁会失败。acceptance_status.json是总体判定。lite_nojvm_checks.mat仅证明传感器级观察器不需要JVM。post_logging_checks.mat记录日志修正后的14+6通过；metadata_checks.mat记录最后一次ideal逐位复查，均不抵消偏置门禁失败。
