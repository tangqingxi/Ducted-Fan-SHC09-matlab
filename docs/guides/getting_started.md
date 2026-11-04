# 快速开始与运行环境

先完成一个短例，再按[研究工作流](research_workflows.md)选择任务。以下命令是使用说明；本次文档整改没有执行仿真、构建或安装。

## 1. 基础环境

已保存验证环境为MATLAB R2025b及Optimization Toolbox；ca_validate_config会检查工具箱许可，分配算法使用linprog/lsqlin等求解器。其他MATLAB版本和非Windows环境未全面验证，不承诺跨平台逐位一致。

基础MATLAB短例不需要Python、ECL或WindTrace。仅使用已有公开源码即可进入平台；原始MAT/WTR、编译产物与本地虚拟环境通常不在Git中。

在终端获取项目，已有工作树跳过此步，不覆盖现有目录：

```bash
git clone https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab.git
cd Ducted-Fan-SHC09-matlab
```

在MATLAB中将当前目录设为该仓库根目录。Windows现有工作区示例：

```matlab
cd('E:/Ducted-Fan-SHC09-matlab');
ca_setup;
```

Linux/macOS或其他克隆位置使用实际目录。ca_setup按文件位置初始化显式路径；不要用addpath(genpath(...))把历史证据和生成目录加入搜索路径。

## 2. 只跑一个2秒短例

```matlab
r = hover_app("PCA_PREDICTIVE");
disp(r.metrics);
```

hover_app调用shc09_airframe两秒position_hold预设，并通过main选择单方法。默认ideal状态反馈，关闭保存结果、保存图和显示图。查看r.config、r.logs和r.metrics即可；该短例不需要ECL二进制，不作正式方法排名。

可选名称为DA_NS、WLS、DCA、PCA_STATIC、PCA_PREDICTIVE；main也保留1～5标志映射。EXAMPLE_PINV为插件开发示例，不计入正式五方法。

## 3. 显式保存一个短例

需要输出时，使用唯一新tag：

```matlab
tag = ['quickstart_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
options = struct('save_results',true,'output_tag',tag);
r = hover_app("PCA_PREDICTIVE",options);
```

输出位于results/<tag>/，包括comparison.mat、metrics.csv、physical_metrics.csv及方法子目录中的log.mat/日志CSV。该例仍不保存图；r.metrics也会在命令窗口显示。平台拒绝覆盖已有输出目录，不设置overwrite_results=true复用正式目录。

这些是平台日志，不应直接交给只接受.wtr的WindTrace，也不保证适用四环研究的导出适配。

## 4. 可选ECL桥接

px4_ecl模式需要MATLAB JVM与build/px4_ecl/px4_ecl_bridge.exe及build_manifest.json。源码位于modules/state_estimator/px4_ecl，依赖身份在third_party/source_manifest.json；构建脚本为tools/build_px4_ecl.py和根build_px4_ecl_bridge.m，需要Python与兼容C++编译器。

当前接口按Windows.exe路径启动外部进程。克隆仓库后不能假设二进制已存在；本次没有重建。若另获构建授权，先审查原构建身份与冻结来源，不能覆盖原二进制后更新旧锁来“放行”。

平台可用shc09_airframe选择ideal/lite/px4_ecl，但仅切换estimator_mode不等于选择四环研究GNSS协议。新研究的1000 s版本需显式使用shc09_gnss_config，见[研究指南](research_workflows.md)。

## 5. 可选WindTrace

WindTrace仍位于apps/windtrace。已有本机安装可打开apps/windtrace/dist/WindTrace/WindTrace.exe并选择单飞行.wtr；EXE和大型原日志不保证随Git提供。开发运行另需Python 3.13及其requirements，安装、启动和离线导出方法集中在[应用说明](../../apps/windtrace/README.md)。

WindTrace只读显示，不生成科学验收结论。无法直接打开某个MAT时先确认它属于哪种日志合同，不通过重跑旧实验“补格式”。

## 6. 运行前检查规模

main默认是单方法30秒任务，main_comparison默认遍历五方法；这与hover_app的2秒预设不同。run_ppid_pindi('formal')和起飞型正式入口涉及多种子完整任务及来源锁；测试套件也可能仿真或写results。具体列表见[运行规模表](research_workflows.md#命令规模与执行边界)。

若遇未知配置、缺桥接、旧锁不匹配或已存在tag，先报告实际入口和错误。不要为让教程成功而改源码、绕过锁、覆盖旧数据或调整阈值。
