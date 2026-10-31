# Stage6A 可重放历史实现

> 文档类型：证据。

四个一次性入口的实现保存在本目录，作为历史证据而非 ca_setup 默认依赖。原 experiments/analysis 路径保留同名包装，按需 addpath 并在结束后恢复；canonical 函数使用 stage6a_ 前缀，避免同名冲突。

[移动清单](../stage6a_manifest.json) 记录原路径、版本化 canonical、原/新/包装 SHA256 与源 tag。原始源码的精确字节仍可由 estimated-comparison-mvp tag 获取；canonical 只调整首个函数声明，算法/配置/输出路径不变。已有报告链接指向原入口仍有效，不修改旧结论。

历史 source_provenance.json 对应当时快照，不要求等于今天的包装文件。活跃 MVP 继续直接使用 analysis/estimator_feedback_metrics_row.m，没有把运行依赖藏入被忽略的 archive。

original_sha256 是移动前工作区字节，original_git_sha256 是源 tag 的规范 Git blob；canonical 与后者只差函数声明名。包装使用 LF，检查不依赖 Windows 换行转换。
