# 四环P–PID/P–INDI八字研究交付

先读 [结果报告](report.md) 和 [正式协议](protocol.json)。五分配器共用控制、EKF和含偏置的CUAV类别误差模型。

`summary.csv`为15条完整飞行的800 Hz离线评分；`state_metrics.csv`为四窗口×十二状态指标。`tracks_10hz/`仅为展示抽取，每条521行，不能替代完整日志评分。`figures/`为PNG/PDF。

`development/`保留第一次伪逆未达标和第二次通过的证据、局部任务原点更改说明及旧F8哈希保护清单。起飞前只用EKF固定局部原点，原始全球坐标误差仍单独报告；不作飞行后真值对齐。

`formal_lock.json`与`sources.json`固定本批数值来源；`reproducibility/new_sources.zip`保存未提交的新研究源码。在基础提交上展开源码、按原工具构建ECL后可研究复现；ECL编译产物哈希不同会触发严格锁，需要另立复现输出和来源记录，不能伪装成本批同一二进制。不得覆盖现有正式锁或原实验结果。

完整MAT和100 Hz轨迹仅在本机results。压缩包不含原始实验数据、第三方完整源码、可执行文件或缓存。`manifest.json`覆盖除自身外的所有交付文件，文本统一LF。可运行 `python tools/package_ppid_pindi.py --verify examples/ppid_pindi_f8_20261101` 校验。

三个种子只描述本批差异，不宣称统计显著性、实机性能或已经验证优先级保护。此批未进行任何旧F8仿真重跑。
