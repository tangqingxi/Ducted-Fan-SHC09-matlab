# 起飞型55秒正式批：单飞行容器

15个.wtr分别对应五方法×501/502/503，不是多方法bundle。manifest.json记录每条的配置、指标、bytes、SHA和源MAT。

双15Hz共享滤波；0–12秒起飞，15–27秒扰动，27–37秒恢复，尾部保持高度、53–55秒收转；没有降落段。

audits逐条核对源MAT、容器字段和指标；replay_summary是代表性501预测PCA的离屏三维检查。容器默认不入Git，清单和README可入Git。

图表单独位于`figures/hover_distance_takeoff_formal_20261103_r1`。禁止覆盖、不得以重飞修复导出问题。
