# 当前仓库地图

本页描述 C5/W4 后的实际布局。运行入口、协议和旧兼容目录仍在原位；C4/C5 已按执行单移动机型、动力学和研究源码，未移动 Results、冻结协议/锁或原始数据。ca_setup只添加显式源码及注册目录，不使用全仓genpath。

## 运行代码

| 路径 | 职责 |
|---|---|
| `main.m`、`shc09_run.m`、`ca_setup.m` | 平台入口、委托运行与显式路径初始化 |
| `apps/` | hover_app等短例、比较应用；experimental/legacy中保留独立和兼容入口 |
| `src/runtime/`、`src/control/` | 总线、调度、控制、PWM 事件与仿真适配；C2 已迁移 |
| `studies/ppid_pindi/` | 独立四环研究实现、传感器协议和来源锁；gnss_v2/为版本化1000 s配置 |
| `studies/hover_distance*` | 对应阶段的场景、协议与运行包装，不是一个可任意混用的统一批 |
| `airframes/shc09/` | SHC09 机型模型与物理参数；模型工厂、配平和名义效能 |
| `dynamics/shc09/` | 动力学积分、气动与 hover 降阶模型 |
| `models/shc09/reference/` | ICGNC 冻结源码/气动表；原字节、原路径，不进入活动搜索路径 |
| `src/control/frame/` | 参考坐标适配器，不属于 Airframe/Dynamics |
| `configs/airframes/shc09_airframe.m` | 场景/应用预设，不是机型身份；改名 DEFER |
| `allocators/` | 显式registry和五种分配器，另有EXAMPLE_PINV示例 |
| `src/effectiveness/`、`allocators/interface/` | 名义效能与兼容分配接口，不能按目录相似就删除 |
| `src/drivers/actuators/`、`src/lib/`、`src/compat/` | 执行器、数学/滤波与仍有调用者的兼容 API |
| `src/navigation/px4_ecl/` | MATLAB/外部 ECL 进程桥接；不是完整飞控固件 |
| `configs/`、`studies/legacy_experiments/` | 公共配置、预设、固定研究协议和实验入口 |
| `analysis/` | 指标、来源摘要、离线诊断、绘图与WTR导出 |
| `third_party/` | 固定版本依赖源码与来源/许可，不任意更新 |

两条控制链的关系见[架构](guides/architecture.md)，命令规模见[研究工作流](guides/research_workflows.md)。

## 文档、回放与证据

```text
README.md                  首次访问者首页
AGENTS.md                  稳定开发契约
HANDOFF.md                 当前状态与下一步
docs/guides/               运行、架构、研究及证据阅读
docs/reference/            技术依据与历史适配边界
docs/validation/           原任务验证、CSV/JSON、报告与图
docs/history/ releases/    历史报告和版本记录
examples/                  轻量交付、复现快照和来源
figures/ logs/wtr/         部分批次的图表、容器索引及交付
apps/windtrace/            仍属于主仓库的回放程序源码
tests/ src/runtime/tests/ 测试、夹具、冻结基线
```

17份codex-repo报告仍在根目录，本阶段未归档或删改。当前文档不再复制其长篇历史进度，证据原文保持不变。

## 本地工件与保护边界

| 路径 | 实际性质 |
|---|---|
| `results/` | 研究原MAT、输入、指标、管理记录，以及历史软件构建等混合布局；通常未被Git跟踪 |
| `build/px4_ecl/` | 现存ECL桥接二进制与构建记录；删除或重建会影响来源身份，不自动清理 |
| `apps/windtrace/dist/WindTrace/` | 当前本机安装运行包；Git克隆不保证包含，保护EXE及整个依赖包 |
| `.venv/` | 本机Python开发环境，不是分发的模型依赖或原始数据备份 |
| `archive/` | 历史索引；实际旧文件存在性以现场为准，不按旧报告路径推定可恢复 |

当前正式批横跨results、logs/wtr、figures、docs/validation，不能因为不在统一目录就移动或去重。[结果指南](guides/results_and_evidence.md)解释关系，独立审计仓库保存文件级计划。

## 尚未落地的目标

`src/`、`airframes/`、`dynamics/`、`studies/` 已由 C2–C5 实施。通用 Results Manager、统一 `results/<study>/<batch_id>/`、WindTrace 独立仓库/Submodule 和主仓库更名仍为后续计划；不得按目标树擅自重排历史 Results 或来源路径。
