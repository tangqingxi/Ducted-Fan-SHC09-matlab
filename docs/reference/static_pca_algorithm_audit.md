# 静态PCA与论文Algorithm 1对照核查

> 文档类型：参考。

结论：当前PCA_STATIC的正常分支、补偿回退和最小范数恢复与截图的数学算法对应。恢复阶段采用零空间投影的等价计算，没有逐行构造增广矩阵。存在数值容差与工程兜底，不能表述为逐行复刻。

## 阶段1：保方向优先级LP

`modules/control_allocator/pca_static/ca_pca_static.m`调用共享核心，并传入predictive=false。此时matrix=B，continued=0，使用静态舵角边界。

- 第一次solve_ray求最大lambda，约束`B*u=vh+lambda*vc`、`0<=lambda<=1`、舵角上下界，对应式29。
- 不可行时第二次solve_ray约束`B*u=lambda*vh`，对应式30。
- 原单纯形求解后检查可行性；零方向或异常结果通过linprog复核，属于数值实现细节。

共享核心为`modules/control_allocator/pca_predictive/ca_priority_core.m`。预测模式才改为仿射预测矩阵和状态延续量，静态模式没有使用动态预测来分配。

## 阶段2：最小范数恢复

截图式38定义`Bbar=[B;ud']`、`vbar=[0;a]`，其中a<0，并使用`uperp=pinv(Bbar)*vbar`。

当前`modules/control_allocator/pca_static/ca_restore.m`在B行满秩条件下计算：

```text
z = ud - B† B ud
uperp = a*z/(z' z)
```

由于`B*z=0`且`ud'*z=z'*z`，此方向满足`B*uperp=0`、`ud'*uperp=a`，也是增广方程的最小范数解。`z=0`等价于增广矩阵没有增加行秩；当前用零空间分量的数值阈值判断，代替显式rank检查。

随后代码计算`ku,opt=-a/(uperp'*uperp)`，按各分量正负计算允许步长，再取`ku=min(ku,opt,ku,max)`并更新`u=ud+ku*uperp`，与截图阶段2对应。

200组随机可行初始舵角，使用截图的字面增广矩阵/pinv版本独立核对：最大输出差异3.3862e-15rad，最大控制效果差异1.5321e-14；均未增大输入范数。原始检查保存在`results/priority_design_20261030/static_pca_paper_audit.mat`。

## 与字面伪代码的细小差异

当前恢复器使用1e-5数值阈值；当零空间分量只有约1e-6rad时会直接返回，而精确秩条件仍可能执行恢复。构造小分量案例中，与精确伪代码差约6.51e-7rad。这是数值容差差异，不是不同的优先级目标。

共享核心还有两次射线均不可达后的mode2高优先级残差最小化，属于预测仿射可达集合可能不含零时的工程扩展，不是截图Algorithm 1的原始步骤。静态对称边界包含零，式30至少有lambda=0的可行解，正常数值条件下不需要此分支。本轮悬停扫幅也未出现mode1/mode2。

## 为什么会与伪逆一致

当阶段1得到lambda=1且伪逆解在舵角范围内时，阶段2可以完整消掉z，最终为`u=B†(vh+vc)`。因此静态PCA与伪逆型分配一致是该算法的预期行为。

0.6N·m的原始日志中，伪逆最大舵角约37.51°，小于40°：静态PCA与DA_NS指令最大差仅5.41e-13°，WLS与DA_NS约4.39e-7°。0.8N·m的伪逆需要约47.56°，静态PCA与DA_NS瞬时指令差达到42.25°，已不再重合。详细核查CSV在`results/ws_gnc_hover_sweep_20261030/allocator_equivalence_audit.csv`。
