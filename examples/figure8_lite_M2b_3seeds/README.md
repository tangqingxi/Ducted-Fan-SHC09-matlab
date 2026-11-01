# M2b / lite 八字轨迹：五方法、三种子

> 文档类型：实验记录。资格为stress，不能作为正式方法排名。

15/15全新仿真完成，失败0，未运行0。保持±40°硬限幅、M2b六通道线性舵效失配和0.6偏航负载；没有修改控制链、物理、估计器、五分配器或数值门禁。水平八字x=2 sin(θ)、y=sin(2θ)、z=-10 m，巡航周期20秒、累计两圈，总长52秒。

三个种子的主窗三维位置RMSE均值：静态PCA 0.881375 m，预测PCA 0.881480 m，差0.000105 m；方法均值差远小于约0.0194 m的种子标准差。本组未观察到预测PCA的位置跟踪优势。五方法均有共同滞后，巡航拟合x约32.7°、y约42.9°；位置外环不使用速度/加速度前馈。

预测PCA相对静态PCA：加载窗姿态误差峰值均值5.86048°→4.26482°（降低27.23%，三种子均下降）；加载窗角速度指令跟踪RMS 9.39982→6.22169°/s（降低33.81%）。DCA对应约4.24397°及6.15444°/s，与预测PCA接近且观测均值稍低，不能认定预测PCA胜过DCA。

代价：预测PCA主窗PWM步变RMS 0.618298°，静态PCA 0.049030°，约12.61倍。预测PCA名义共同预测力矩残差约6.32e-17 Nm，但实际与名义舵效力矩差RMS反而从0.085958增至0.095848 Nm；不能把名义残差接近零解释为实际力矩准确。

主窗最坏姿态跟踪误差峰值5.345026°，超过既有5°门禁，因此整体为stress；饱和0%，估计姿态RMS最大1.600464°，气动越界0。种子2的DA-NS峰值位于43.015秒，当时估计姿态误差3.19447°，舵角约27.2°，未触硬限幅。旧悬停rankable不能直接套到新轨迹。

十二状态为NED位置/速度、SHC09姿态欧拉角和机体角速度。位置目标共同给定、速度目标是几何导数；姿态和角速度目标取各次运行的实际控制指令，不是十二个独立外部指令。箱线图每箱n=3，叠加全部原始点及同种子配对线，不把时间采样作为独立试验，不作显著性声明。

[完整报告](report.md) · [协议](protocol.json) · [可比性](comparability.csv) · [验证汇总](validation_summary.json) · [独立重算](independent_checks.json)

[十二状态箱线图](figures/boxplot_12states_rmse.png) · [加载瞬态箱线图](figures/boxplot_load_transients.png) · [效果与代价箱线图](figures/boxplot_tracking_allocation.png)

[预测PCA十二状态目标/跟踪](figures/PCA_PREDICTIVE_12states_seed1.png) · [静态PCA十二状态目标/跟踪](figures/PCA_STATIC_12states_seed1.png) · [五方法轨迹](figures/figure8_five_methods_seed1.png) · [配对差值](figures/paired_pca_12states.png)

[复现指南](../../docs/guides/figure8_lite_comparison.md)。七组图均保留同名PDF。完整800Hz MAT和100Hz跟踪CSV只留在本地results/figure8_lite_M2b_20261101_figure8_3seeds；这里保存可提交的轻量指标和图表，没有复制完整日志。

参考解析导数测试通过；十五条MAT日志和720项十二状态指标独立核验通过，CSV最大往返差5.329e-15；六组冻结基线完整非耗时SHA、PWM及样本逐位一致。没有重跑旧60/60、E1/E2或M4。既有LitePhysicalBias 0.05°/s预期失败未修、未放宽。

后续[优先级与论文审计](../../docs/reference/figure8_priority_audit.md)确认：运动主窗内两种PCA的λ均严格为1；预测PCA仅在启动前约12毫秒有16个候选缩放点。原实验真实舵机与舵角估计模型完全匹配，因此本组不能作为受限优先级保护或实机预测精度的证据。上面的加载改善是观测结果，未做消融，不能直接归因于优先级机制。
