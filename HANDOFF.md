# HANDOFF — PX4命名日志视图完成（仅工具分支）

- **Last updated:** 2026-10-31T23:33+08:00（Asia/Shanghai）。
- **当前分支：** px4-log-view。
- **工具内容提交：** c56f23619ce47963032e537bdef543334a026628，`tools: add PX4 log view and MAT/CSV export`。
- **最新HANDOFF提交 / 当前HEAD：** 以git log -1为准，本文件按交接协议单独文档提交。
- **发布基线：** main与v0.5.0剥离提交仍为3fc46c0247fea6e82c95e38721f56fa256bf3b72；v0.5.0 tag对象0b238275cbe01ee26c51758e3d923468c06c2d21。
- **本轮不发布：** 未合并main、未创建新tag、未push。工作分支只保留本地，提交后工作区干净。

## 1. 本轮完成

只新增离线PX4命名视图与MAT/CSV导出。内部topic、Shc09Bus、模块接口、控制器、五分配器、估计器、物理与既有log字段全部不动；没有改门禁或数值结果。没有ULog/.ulg产物、PX4固件或ECL运行依赖，没有重跑60/60主比较或E1/E2。

核心交付：

- [analysis/px4_log_view.m](analysis/px4_log_view.m)：值结构视图。
- [analysis/px4_log_export.m](analysis/px4_log_export.m)：读log结构或含log/L的MAT，写px4.mat、px4_log.csv，禁止覆盖已有输出。
- [docs/px4_log_map.md](docs/guides/px4_log_map.md)：字段、帧、单位、来源、缺失值及消息语义差异。
- [tests/test_px4_log_export.m](tests/test_px4_log_export.m)：转换与两秒实际日志的只读导出验证。

文档索引及已有文件清单同步维护；验证证据位于docs/px4_log_validation，完整MAT/CSV留本地results，不入Git。

## 2. 重要映射与边界

C=[0 1 0;-1 0 0;0 0 1]，q=quat(R*C')表示FRD body→NED，Hamilton标量在前、单位化、q0≥0，原R留shc09.rotation。显式rotation优先，否则由原euler_rad重建。vehicle字段是已记录物理状态的离线命名视图，不伪装成原生估计topic；测量/估计量另存shc09原始列。

位置/速度保持NED；机体系omega、alpha、torque、thrust及原始加计/陀螺/磁场向量转FRD。v_h/v_c原样保留，先在原机体系用名义J算tau=J*(v_h+v_c)，再转FRD。vehicle_torque_setpoint.xyz按任务约定存Nm；这区别于PX4原生归一化torque消息，导出不能直接作为固件消息回放。

推力是k_T0*motor_rad_s²的静态代理，沿原机体-z，非气动总力或已记录的原生推力指令。最大转速对应推力作为归一化基准，标准SHC09为41.70816N，基准保存在meta；缺参保留raw并使无法计算的字段NaN。舵机按六维上下界线性归一化到[-1,1]，导出限幅时保留原命令、未限幅值和越界标志。缺界不能填假控制量。

秒时间不排序、不平移；微秒uint64=round(time_s*1e6)。CSV浮点用17位有效数字，保留double往返。传感器只从原始平面字段或topic快照取数，有明确采样时刻才写有效timestamp_sample；未知/负采样秒保留raw，unsigned列为0且valid=false。稀疏观测不保持或插值，不从真值生成传感器。GNSS有navigation_origin才做球面反投影，否则lat/lon/alt为NaN并保留NED。

## 3. 验证

- 新导出测试通过：8帧合成夹具包含非对角J和接近180°姿态；C正交、q单位模与往返、NED不变、名义力矩、FRD轴、归一化、时间、CSV列名、原始量、缺参NaN、稀疏传感器及采样时间均通过。
- 四元数往返最大矩阵误差2.6185e-16；含低位扰动的double时间及q列从CSV精确读回；原输入log保持不变。
- 一个2秒实际日志导出1601行、171列；没有.ulg产物或依赖。
- run_project_tests(false)：14/14。
- test_platform_baseline：六组完整非耗时日志SHA、PWM和冻结指标逐位一致，最大差0。
- 数值引擎仍26778efe81951624e488fb4efd0bec08e6fcc44cf6da5450ce799c8ac5d08286。两组最终MATLAB进程正常退出0，没有运行进程遗留。

[最终导出测试](docs/px4_log_validation/export_final_v2_checks.json) · [验证总记录及源码SHA](docs/px4_log_validation/checks.json) · [旧回归](docs/px4_log_validation/regression.json) · [14项明细](docs/px4_log_validation/project_tests.csv) · [冻结基线](docs/px4_log_validation/baseline.csv)。中间通过记录仍保留，最终版本以export_final_v2_checks为准。

## 4. 导出位置与复现

- CSV：results/px4_log_export_20261031_232821_590/smoke/px4_log.csv。
- MAT：results/px4_log_export_20261031_232821_590/smoke/px4.mat，变量px4。
- 同目录上级input_log.mat含两秒原log/c/r，可供离线重导出。
- 最新新测试日志：archive_px4_log_export_final_v2.log；旧回归日志：archive_px4_log_baseline.log。此前调试/通过日志保留，不删除旧证据。

```matlab
ca_setup;
files = px4_log_export( ...
    'results/px4_log_export_20261031_232821_590/input_log.mat', ...
    'results/px4_export_another');
```

每次使用未存在的输出文件名所在目录。可显式传model/cfg；直接结构要有原始time_s/time_for_metrics，无时间列的MAT仅取ref/r.time_s，不猜时钟。CSV点号列名用VariableNamingRule='preserve'读取，需要uint64时显式指定导入类型。

## 5. v0.5.0基线保持

已发布v0.5.0的60/60及四组rankable结果原样保留，本轮没有重跑或重新发布。lite主窗峰值仍为原记录3.7749°/3.7817°、饱和0%、估计RMS≤1.316°、气动越界0；ideal对v0.4完整非耗时日志一致的发布证据仍在原目录。lite仍experimental、默认ideal，物理偏置0.05°/s门禁的预期失败未修，本轮未重新评价偏置。

[发布说明](docs/releases/release_notes_v0.5.0.md) · [发布验证](docs/release_validation/v0.5.0/release_checks.json) · [比较报告](examples/lite_comparison_v050/comparison_3seeds/report.md)。完整正式数据仍为results/allocation_comparison_v050_comparison_3seeds；旧35/60暂停快照、v0.4数据和缓存均保留。

## 6. 当前状态核验与停止

```powershell
git status
git branch --show-current
git log --oneline -3
git rev-parse refs/heads/main
git rev-parse 'refs/tags/v0.5.0^{}'
git ls-remote origin refs/heads/main refs/tags/v0.5.0 'refs/tags/v0.5.0^{}'
```

当前应在px4-log-view，工作区干净；main/远端main及v0.5.0剥离提交保持3fc46c0。工具内容及本HANDOFF只在本地工具分支。未经用户明确新指令，不合并main、不tag、不push。本轮完成后停止，下一步等待用户新任务，不启动其他功能。

硬边界继续保持：不改控制链、Shc09Bus、物理/气动、五算法、估计器、旧协议和5°/10%/2°/气动域门禁；不生成ULog、引入PX4固件依赖、跑60次主比较/E1/E2或参数不确定性。不git clean/reset，不删旧证据。禁止读写 `C:\Users\32450\Desktop\专利\control_allocation\comparison_simulation`。每次结束/暂停/失败按交接协议更新本文件并单独文档提交。
