# 本地历史与日志归档

> 文档类型：证据。

archive保存历史副本和本机运行证据，不参与当前构建，不加入ca_setup路径。不要把其中的重复源码当成活跃数值实现，也不据重复就删除。

- [运行日志索引](logs/README.md)：原根目录archive_*.log按原文件名归档到logs，按主题分组。
- [仓库地图](../docs/repository_map.md)：区分当前源码、文档、历史和生成物。
- [当前交接](../HANDOFF.md)：判断当前分支、已验证内容和后续边界。

Git只保存本说明及logs/README.md；真实日志和其他历史副本继续忽略。克隆仓库不自带这些本机日志，因此索引以文件名和摘要记录，不把缺席的本地日志链接误当发布文件。已有历史报告中的根目录日志名可按同名在logs下查找。

本轮未移动results、third_party或docs/evidence，没有删除任何日志；build和.tmp_matlab也保留。
