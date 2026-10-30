# 数值与源文件冻结基线

源提交3d41369，MATLAB R2025b。numeric_baseline.mat为738997字节，含20秒M0/DA_NS和两秒五方法，共六组；保存全部旧非耗时日志字段SHA256、精确PWM更新/源时间、401个稀疏数值样本及whole指标。它是已有协议的冻结回归输入，不是新的科学结论或统计重复。

从根目录运行`ca_setup; report=test_platform_baseline;`，逐字段比较完整SHA、PWM数组、样本和指标；新增topic_log不属于旧基线字段。只排除桌面求解/总耗时和导航计时，不放宽数值容差。没有重跑30次正式阶梯。

`protected_sources.json`记录254项物理/驱动、控制器/算法、协议、第三方/参考/夹具及既有轻量示例。固定路径保持，算法和控制器允许原样搬迁。开工时CRLF原字节SHA及原Git提交LF blob SHA均保留，校验接受任一以便新克隆；算法内容没有修改。运行`python tools/verify_platform_sources.py`检查；本地原results另有大小/修改时间保护快照，归档目录未提交。

stage0 CSV/JSON记录冻结验收；stage1记录14+3；stage2六个checks.mat记录逐模块14旧测试与六组基线，各自五入口smoke；stage2_navigation记录官方ECL导航。stage3记录14+5、六插件契约与基线；stage4记录最终14+6、五入口、JVM导航、README运行和旧格式重绘。结构化记录为小型MAT/JSON/CSV，完整本地diary位于被忽略的archive/platform_refactor。

[平台重构报告](../../docs/platform_refactor_report.md)说明提交、结果和边界。源码/协议/原始数值基线不可为了通过回归而更新。
