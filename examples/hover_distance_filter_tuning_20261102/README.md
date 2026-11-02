# hover_distance六组INDI滤波工程调参轻量证据

[调参报告](analysis/report.md) · [逐条及配置均值](tuning_with_means.csv) · [复核图](analysis/figures/02_finalists.png) · [时间对齐诊断](phase/phase_alignment_note.md)

六组501粗扫12条、最优两组502/503复核8条，20/20完整有效。只覆盖plan中的H1/H2，按两方法、三种子等权滚转0.5Hz残差选择，不按PCA排名或跟踪误差选择。

建议15/15 Hz：滚转残差均值4.74103%，种子标准差0.423837个百分点；502均值5.19605%，六条中4条低于5%。三轴范数均值25.5558%并列报告。不宣称逐种子全部达标或泛化确认；没有加入相位超前，没有运行新的五方法15条。12/12复核均值5.87363%。

本包不包含MAT、完整时序/几何或构建文件。原始证据仍在各新results目录。source_provenance.json记录复制来源，manifest.json覆盖除自身外的本包文件；内层历史manifest按原字节保留。后续正式批必须由用户决定并另立记录。
