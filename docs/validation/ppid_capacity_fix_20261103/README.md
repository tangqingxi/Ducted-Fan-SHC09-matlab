# PPID容量修复轻量证据

[完整报告](../../../docs/history/ENGINEERING_HISTORY.md) · [精确补丁](capacity_fix.patch) · [管理性例外](administrative_exception.json) · [独立字节表](independent_bitwise.csv)

40秒改前／改后，以及旧50秒起飞预检／改后，两组各37个数组原始字节相同；55秒44001状态点，容量18317、实际PWM事件18316，无越界／非有限状态。这里不包含重型MAT，完整新回归数据留results/ppid_capacity_fix_20261103_r1。

旧F8锁没有引用该文件，旧PPID与takeoff锁不改，26份锁文件SHA逐一验证相同。新来源锁是在验证通过后建立，不冒充飞前正式锁。不能据此续跑旧正式批或扩大仿真。

计时字段不参与确定性比较，EKF频率元数据按新分母修正。初版验证器多速率数组横拼错误只发生在MAT保存之后，已用只读检查恢复证据，没有重飞基线。

manifest.json逐文件记录本轻量包SHA。没有运行F8正式批、没有提交／push。
