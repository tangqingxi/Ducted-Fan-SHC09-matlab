# 55秒地面坐标起飞型hover_distance

新协议为protocol.json，独立于旧40秒及50秒协议。共享PPID-PINDI、M2b、原舵机失配、ECL与CUAV误差模型、400Hz分配／333HzPWM；滤波由plan.controller固定15/15Hz。

时间线：0–12秒五次平滑爬升到NED−10米；12–15秒稳定，偏航12–14秒起振；15秒开始加载85%滚转权限、0.5Hz滚转力矩，27秒开始卸载，加载／卸载均0.5秒，与旧实现只差整体平移5秒。偏航±280°/s、0.75Hz，主窗[15,27)，恢复窗[27,37)。37–55秒保持高度、53–55秒收转，没有降落或接地模型。

## 来源与入口

- hdtf_config：只覆盖时长、初始位置、参考、扰动时间及指定滤波；断言其他配置和对象模型不变，断言主窗波形与旧工况平移一致。
- hdt_reference沿用此前独立参考生成函数，解析五次位置前馈与偏航积分。
- hdtf_metrics：800Hz状态／400Hz分配／333HzPWM分别计量；估计＋真值分开，不事后平移。原1e-7rad舵指令容差；恢复时间未达到保留NaN。
- hdtf_sources：共同引擎、父研究源、ECL二进制、新场景、导出器单独记录；不更新任何旧锁。
- run_hover_distance_takeoff_formal：预检一条，合格后五方法×501/502/503共15条，所有输出目录必须全新。

原20261103_r1驱动在首条DA_NS已保存／导出后出现指标累加器初始化错误。原错误日志、源码冻结摘要、成功MAT和.wtr保留。独立管理性续跑位于research/hover_distance_takeoff_formal_recovery_20261103，只读取已冻结输入、补14条not_run；没有重飞已完成飞行，不改数值源、门槛或参数。实际最终状态以本批completion.json、根报告及交接为准。

本批已完成15/15并导出15份容器。全部飞行结束后，当前hdtf_run仅修复空累加器字段和缺失error_id字符串，供未来新tag使用，没有再仿真；本批原始驱动副本与old/new SHA、精确diff保留在docs/validation/hover_distance_takeoff_formal_20261103_r1。旧协议／锁不改，不能把当前管理修复版SHA替换成本批历史SHA。

metrics内precheck_passed只供先决PCA_PREDICTIVE判断，非PCA不适用；正式运行和有效性分别看status／data_valid。完整分析见根codex-repo-17.md，不以单个λ最小值设额外门槛。

## 交付与命令

首要交付为logs/wtr/hover_distance_takeoff_formal_20261103_r1内每飞行一个.wtr，manifest记录method／seed／滤波／工况／指标／bytes／SHA和源MAT。容器默认不入Git。图在figures/同名批次，七组主图、每方法一页501十二状态附录和三种子极值表。

```matlab
run_hover_distance_takeoff_formal('20261103_r1'); % 历史运行命令；已有目录拒绝重跑
```

```powershell
python tools/deliver_hover_takeoff_formal.py hover_distance_takeoff_formal_20261103_r1
python tools/check_hover_takeoff_replay.py hover_distance_takeoff_formal_20261103_r1
```

入口需WINDTRACE_PYTHON指向含SciPy环境。后处理和离屏回放不调用仿真，也不改GUI布局。全部新结果拒绝覆盖，不以导出／绘图异常为由重飞。旧结果、锁、协议、main不改，不提交或push。

地面坐标起始采用原悬停转速配平；没有解锁、起转、接地、地效。本批是工程调参配置下的比较，501包含先决预检，不是独立泛化确认；不宣称显著、实机优势或全局最优。
