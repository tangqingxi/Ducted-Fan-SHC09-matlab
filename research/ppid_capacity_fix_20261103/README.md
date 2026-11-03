# PPID容量与统计修复回归

只改ppid_simulate.m两处：PWM按参考终点与cfg.pwm_hz分配，EKF频率分母按参考跨度计算。不改调度、控制、对象、参考、分配或扰动；ppid_config父参考41601点断言和hd_run覆盖保留。

没有新的固定时长上限；MATLAB数组仍允许增长。+2是预分配余量，实际日志不补点：40秒13321、50秒16651、55秒18316个PWM事件。

```matlab
root=ca_setup();addpath(fullfile(root,'research','ppid_capacity_fix_20261103'));
pcap_run('before40'); % 只能在旧源码、首次生成基线时调用
% 应用精确补丁后执行，已有结果会拒绝覆盖。
pcap_run('after40');pcap_compare('40');
pcap_run('after50');pcap_compare('50');
pcap_run('after55');
```

结果在results/ppid_capacity_fix_20261103_r1。50秒直接复用保留的takeoff输入和MAT；55秒在新输入中延长时长，使用原hdt_reference，不修改旧协议。

pcap_compare核对原始字节，含NaN载荷和正负零，共37个状态／决策／时序数组。计时和ekf_rate_hz元数据单列。首条40秒MAT保存后，初版检查横拼不同采样率数组报错，已改为只读该MAT分开核验，没有重飞，旧验证脚本保留。

旧F8锁未引用ppid_simulate；旧PPID／takeoff锁保留原SHA，不更新或冒充匹配。精确diff、old/new SHA、管理性说明及新来源锁都另存本次结果目录。不要改旧锁绕过正式驱动保护。
