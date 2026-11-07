# C3/W2 精确执行审批请求

状态：PENDING_USER_APPROVAL。建议有条件批准下列完整范围；本Gate本身不构成C3执行授权。

固定基准DEV refactor/phase3-source@269564dbc53a4ca4da70d9209dc3e5fa5a0c20e1，main保持fdc933694db9c16a0d9ffcd6d9c391b052352d22。执行单v1 SHA256 `e2a63faf87830338df97e172e95a1b3036c33c1a5e5832244565f929529a7e4f`。

## 请求范围

- 五条MOVE：effectiveness_for_model、effectiveness_registry、hover_linear_effectiveness、shc09_6vane_effectiveness、shc09_nominal_effectiveness，按CSV完整路径git mv到src/effectiveness对应位置，源raw字节保持。
- 原W2的33分配器文件KEEP为最终方案；顶层registry、六算法/包装/句柄、allocators/interface均不改。src/allocation只留规划；禁止allocators/plugins。
- 配套文件1：analysis/allocation_comparison_engine.m仅加入src/effectiveness显式覆盖，保持原哈希算法与去重/同名拒绝；记录旧C2及新C3 engine，保护历史锁。
- 配套文件2：tools/check_phase3_static.py精确绑定C2基准/W2执行单/MOVE5/KEEP33/DEFER1、C2全raw清单和三份配套白名单；效能注册文件按唯一实际路径读取，工厂优先新目录，不被旧空目录误导；拒绝任意额外变更。
- 配套文件3：effectiveness/README.md仅修改第5、16行的两处链接，具体原/新目标与候选SHA见[DOCUMENT_LINK_IMPACT.md](DOCUMENT_LINK_IMPACT.md)。文件不迁移，不改其他文字，不覆盖src/effectiveness/README.md。

不需修改ca_setup、五份MOVE源码内容、registry返回字段、ppid_source_manifest、allocation_comparison_hash或.gitattributes；若执行中发现这些需要改变，保留证据并重新说明范围，不自行扩大。

## 验证、提交与停止

只授权静态/原字节、MATLAB路径及句柄/engine计算、Git blob和独立检出检查；不调用工厂推进对象、不运行控制仿真、ECL或全套测试。三配套与五移动作为一个可独立回滚的C3提交，验证全通过后普通推送开发分支及轻量审计证据。

执行前如HEAD、source raw SHA、目标状态漂移，立即停止核对。历史协议、锁、MAT/WTR、EXE与指标不变；历史a3f ECL二进制恢复UNRESOLVED不在本范围处理。审批不包含C4、模型迁移、研究目录移动、main合并、仓库改名或其他文档修订。

获批后第一步重新核对本执行单与目标状态，执行顺序及验收见[ROLLBACK_AND_VALIDATION_PLAN.md](ROLLBACK_AND_VALIDATION_PLAN.md)。未获批保持DEV只读。本轮Gate推送后停止。
