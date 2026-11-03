# PPID仿真时长容量与EKF统计修复报告

日期：2026-11-03（Asia/Shanghai），分支hover_distance。只修改共享ppid_simulate.m的容量预分配和统计分母两处；控制器／对象／参考函数／分配器／调度器／扰动算法不改。没有提交、push或重跑F8。

## 修复与适用边界

旧PWM预分配两数组固定ceil(52*333)+2，现为pwm_capacity=ceil(ref.time_s(end)*cfg.pwm_hz)+2，再分配两个数组。EKF频率分母52改为ref.time_s(end)-ref.time_s(1)。原日志按count裁剪逻辑保留，hd_run包装覆盖保留，ppid_config的41601父参考断言未动。

MATLAB数组本来允许自动增长，因此旧52秒不是不可突破的硬上限；本次消除的是写死的预分配和统计值。按用户后续“无固定上限／自动扩展”的要求，不另设总时长上限，每次根据实际参考自动计算容量。真实事件日志不填虚假点：55秒333Hz、含0秒共有18316个事件，18317是含余量的预分配容量。

| 源文件 | SHA256 |
|---|---|
| 改前 | e65e0605a87c850ed344cb659d51d61dba916a954a1b2020166b37db1dfc3995 |
| 改后 | bcced6b660466465e28ed62d6d1529b56dffddde0a43777e86e2018891468fb3 |

[精确unified diff](docs/validation/ppid_capacity_fix_20261103/capacity_fix.patch)包含全部修改；独立脚本逐字节断言新文件恰好等于约定两处替换，无其他内容修改。

## 基线与回归

全部新验证均为seed501、PCA_PREDICTIVE、15/15Hz，未使用正式批驱动。40秒无起飞配置／噪声在改前一次生成并保存input40.mat，改后直接复用；50秒直接读取已保留的原takeoff inputs和MAT。55秒仅在新验证输入延长时长／尾段，继续调用未修改的hdt_reference，不回写原50秒协议。

| 用例 | 状态点 | 真实PWM事件 | 实际预分配 | EKF统计Hz | 结果 |
|---|---:|---:|---:|---:|---|
| 改前40秒 |32001|13321|17318|76.9230769|新基线保存 |
| 改后40秒 |32001|13321|13322|100|37个数组逐字节一致 |
| 改后50秒 |40001|16651|16652|100|与原起飞预检37个数组逐字节一致 |
| 改后55秒 |44001|18316|18317|100|完整运行、容量余量1、状态有限 |

必检position／omega／v_h／lambda／pwm_command在两组回归均逐位一致；MATLAB以typecast核对原始字节，包含NaN载荷和正负零。最大物理差异为0。Python独立读取两组MAT再比这五项，共10项原始字节／SHA完全相同；update_counts也一致。完整字段证据见[40秒](docs/validation/ppid_capacity_fix_20261103/comparison40.json)、[50秒](docs/validation/ppid_capacity_fix_20261103/comparison50.json)和[独立表](docs/validation/ppid_capacity_fix_20261103/independent_bitwise.csv)。

solve_time_s／elapsed_s是非确定性计时，单列不作为物理回归。ekf_rate_hz是本次明确修复的元数据：旧40秒用52作分母才得到76.923；新值100Hz。旧50秒日志早已由包装层修正到100，因此新旧该值也一致；其他物理数值没有因本补丁改变。

55秒全状态有限，估计器每拍有效性断言通过，气动越界0；命令舵角按原1e−7rad容差、真实舵角／舵速按原物理硬限核验通过。实际pwm_time长度18316、最后时间55秒，未改变调度时刻或人为补点。请求中“实际长度≥55*333+2”将事件数与容量混用；此处按后续自动容量口径分别报告，不谎称实际日志有18317点。

## 锁、引擎与管理性记录

B0识别27处历史来源引用、26份锁文件；旧F8数值锁没有ppid_simulate条目，故不需要修改F8锁或启用hover数值副本。research/ppid_pindi/formal_lock.json及旧takeoff来源锁继续保留旧SHA，全部26份前后逐一核验未变。旧锁与新源码不匹配时，应拒绝追加旧正式批；不得据此修正旧锁冒充旧结果用新源码生成。

[管理性例外JSON](docs/validation/ppid_capacity_fix_20261103/administrative_exception.json)记载old/new SHA、完整diff、未改变数值逻辑的声明、旧锁逐项哈希、验证与边界；[新来源锁](docs/validation/ppid_capacity_fix_20261103/new_source_lock.json)独立保存新源码和验证器SHA，明确为验证后建立，不是旧正式锁的更新。

引擎指纹仍为d4c19f329e92fb6b0b272498837d926e33312846d32f31fc35622b6f518cb750，因为research不在allocation_comparison_engine覆盖范围；引擎不变不能替代显式来源核验。40/50秒用例处于原52秒范围内并已实测逐位一致；0起点52秒时两个新表达式与旧值代数相同，没有重跑52秒F8正式批，不将这两例外推为任意输入实测证明。

清理任务A已移除ECL编译物，验证前按同一归档源码／编译器参数重建。原50秒桥接文件SHA为e9bee1e5b8d296c92e3392605fc2e1eb200fc763bff97911a2ae961c79bde589，重建为a3f01863525b1cb8f6c54cc2b5ea46e1b1bc0858685febdd74b13986b78a26b2；B前后新运行始终使用同一重建二进制。虽文件SHA不同，旧50秒回放计算的37字段仍实测逐位一致；不声称两个EXE本身逐位相同。

首条40秒MAT保存之后，初版验证工具误将800Hz状态与333Hz PWM横拼，检查报错。已只修正验证器、直接读取同一MAT补核验，没有重复飞基线；[修正记录](docs/validation/ppid_capacity_fix_20261103/validation_tool_correction.json)保留旧工具和diff，不把检查错误写成飞行失败。

## 交付与停止状态

重型证据：results/ppid_capacity_fix_20261103_r1，包含改前／改后40秒、改后50/55秒MAT、固定输入、37字段JSON、逐位CSV、原始进度日志、old/new源码快照和精确patch。本次实际新对象仿真4次（40改前、40改后、50改后、55改后），其中基线一次，没有F8仿真或15条正式批。

[轻量证据目录](docs/validation/ppid_capacity_fix_20261103/README.md)保留上述关键JSON／CSV／patch及SHA清单，不含MAT。验证代码在[专用说明](research/ppid_capacity_fix_20261103/README.md)。旧40／50协议、旧原始结果、当前.wtr和旧锁不改。清理清单补记保留重建build桥接与本次新验证目录，防止按任务A旧范围再次清除。

容量修复已经验证完成，仍未授权新的五方法正式批；不自动开展后续实验。未提交、未push、main和Git HEAD保持不变。
