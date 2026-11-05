# C2/W1 审批请求

日期：2026-11-05。申请状态：**PENDING_USER_APPROVAL**。本轮只完成Gate，不执行申请内容。

建议：**有条件批准下列完整C2范围**。历史engine门槛已解释并复现；路径/目标清单具备执行条件。须将下面四项配套修订同时纳入授权，执行后验收通过才能推送C2；不建议批准仅70条文件移动而缺少配套修订的方案。

## 请求批准的具体范围

- 在DEV refactor/phase3-source@b2a287ceff34445bb7902890141be7a450d19de9之上执行W1_RESOLVED_PLAN.csv的70条MOVE（69m+1cpp），原字节不变；9条KEEP、2条DEFER_W6原位保留，禁止覆盖目标。
- 修改analysis/allocation_comparison_engine.m的显式目录覆盖以纳入本波新路径，保留原历史实现的固定提交引用，登记C1旧ec→C2新engine及PPID来源身份；不追改历史锁。不修改allocation_comparison_hash序列化算法或数值代码。
- 修改tools/build_px4_ecl.py中的桥接源路径查找，保持编译参数、第三方依赖及输出位置；仅静态验证，不运行构建、不改exe或历史build_manifest。
- 修改tools/check_phase3_static.py，使其严格验证本执行单允许的移动及明确配套文件，原始raw SHA与未动文件保护继续强制；补充必要的轻量验证记录。
- 在.gitattributes末尾增加风险文档列出的7个精确目标-text规则，无BOM UTF-8；不全局改换行、不renormalize。用发布blob与独立检出证明70项目标raw SHA可保留。
- 以一个独立C2提交包含上述移动和配套修订，普通推送开发分支；更新必要的轻量审计证据。回滚普通revert并按执行单恢复可能变化的7份原raw字节。

## 允许的验证与边界

只做静态、逐文件SHA、MATLAB which -all/重复初始化/注册句柄/engine来源计算、临时独立检出字节检查。默认**零新控制仿真、零ECL进程、零重建**。任何短例或其他运行预算另行明确批准。

不实施C3/W2或后续波次，不合并DEV main，不改算法/控制参数/GNSS模型、历史锁/MAT/WTR/协议/指标，不拆WindTrace、不重命名仓库、不实施Results Manager。不处理C3前才需统一的allocators/plugins历史计划矛盾。

## 批准后的启动与验收

执行前再次核对HEAD、源SHA和目标不存在；任一漂移均暂停重新核对。四项配套修订未完成时不得提交一个宣称C2验收通过的纯移动版本。验收需70raw一致、69新路径which正确、六分配器/两效能/14句柄有效、新engine完整覆盖、历史数据零变化、发布字节可检出、回滚计划可实施。具体见[回滚与验证方案](ROLLBACK_AND_VALIDATION_PLAN.md)。

历史ECL二进制恢复仍为UNRESOLVED，见来源报告；当前exe与build_manifest记录不一致。本申请只保持当前a68d二进制原字节，不修旧元数据、不重建，也不声称历史ECL环境已恢复。此限制须随C2保留。

当前没有请求执行C2的已生效授权；本文件只提供具体可审查的后续审批范围。用户未批准前保持DEV只读。
