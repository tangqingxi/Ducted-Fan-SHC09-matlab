# 旧结果清理与WindTrace可用运行包保留报告

日期：2026-11-03。分支hover_distance；全程没有提交、push、reset、git clean或删除分支。保留此前未提交的起飞变体，数值源码不改。

## 体积与执行

清理前25461745120字节，约25.46GB／23.713GiB。三tier删除357个清单原路径、25245359515字节：

| tier | 内容 | 释放GiB |
|---|---|---:|
|1|旧WindTrace构建、运行包和缓存|5.261|
|2|旧实验／日志／轨迹与非保留批|17.208|
|3|归档副本、MATLAB临时目录、根build、测试缓存|1.043|

删除前保守留存3584份关键CSV／JSON／报告／锁与SHA，1462149351字节，避免专利和历史引用断档。后续用户明确要求正常可用WindTrace，因此重建并保留约0.60GB运行包；最终仓库约2.29GB／2.13GiB，results约1.51GB／1.40GiB。删除字节数不等于净缩减，因为有引用副本和重建运行包。

[当前清单](cleanup_manifest.csv)含path、size、mtime、keep/delete、reason、referenced_by。原三tier执行清单另存current_summaries/cleanup_20261103_r1/cleanup_manifest.executed.csv，SHA为868262bf010f6c4d8734f82b3e2d308936882adbbb6124e0bd4aeeb81c42d960。后续修订把apps/windtrace/dist改为keep，新临时构建列入delete并清除；manifest_amendment.json说明原因，不把旧包删除与新包保留混淆。

## 保留与证据边界

全部源码、Git历史、configs／docs／tests／platform／allocators／models、所有examples未删。archive保留两份Git README；没有为“整目录删除”违反不删Git文件规则。

results只保留：f8_work_20261101、f8_reference_20261101、current_summaries、hover_distance_takeoff_precheck_20261103_r1及hover_distance_takeoff_work_20261103_r1。logs/wtr当前50秒容器及manifest／回放证据、figures当前四组图完整。

f8_reference含确认status／summary／任务与状态指标／独立核验／priority_activation及events／报告、基础指标和汇总、压力筛选与入选记录、协议和锁SHA。PPID正式summary／report／任务表在current_summaries；原批不存在task_metrics.csv，该保留文件明确为原summary.csv逐字节别名。F8确认summary来自已提交aggregate_metrics原字节副本，基础summary只是原列拼接，均未重算或改数值。

只读核对用户指定的专利交底书：它文字引用旧40秒hover工况、仿真图8／表2仍待补。已保存该批关键表和λ／mode事件，专利原文件未改。引用映射在reference_redirects.csv，逐文件来源和SHA在两个参考目录的copied_files.json。

旧F8／PPID／40秒hover／滤波的MAT与完整状态轨迹已清理。现有CSV和examples可以复核保留数字，无法再从已删MAT重算全部指标或回放旧飞行；原锁／pipeline记录是历史证据，不表示大文件仍在。当前50秒源MAT和.wtr仍可逐字段核对。

根build内ECL编译桥接也已按清单删除，未来仿真先按build_px4_ecl_bridge.m重建，不能改旧来源SHA追认新二进制。本轮没有运行任何仿真。

## WindTrace正常使用

运行位置仍是E:/Ducted-Fan-SHC09-matlab/apps/windtrace/dist/WindTrace/WindTrace.exe；原桌面快捷方式目标存在，无需改地址。

源码与旧包运行源SHA完全一致，仅重新打包；当前EXE SHA256：71a682e941b33b17660f8cd7c1fcc865a2765290fb13dba21e27017d441f3e5c。安装逐文件校验通过，2436个文件、约599MB。当前50秒.wtr读取、空启动、446项只读参数搜索及普通Windows三维／网格旋转四项检查通过，机体与网格截图已核验。窗口短暂显示后自动关闭，无Computer Use／鼠标注入；欢迎页最近日志改造仍未实施。

本轮临时构建最终移入apps/windtrace/build并在安装核验后按修订清单清除，最终只保留apps/windtrace/dist运行包。没有为清理测试依赖开发环境运行：EXE从独立工作目录、Windows最小PATH验证。

## 完整性与交接

删除前1509个保留文件SHA核验一致，1425个Git跟踪文件全部保留；后续只更新AGENTS／HANDOFF清理说明，其他源码和既有交付继续逐文件核验。current.wtr严格读取通过：50秒、18topic、446参数、unknown=0，SHA保持40536170eeecacba8f062d8ecd932d42f8e194f045ecd1d97ef58928b5164c3b。

清单、目录快照、原／新manifest SHA、三tier记录、复制SHA、前后体积、重建／安装与窗口截图在results/current_summaries/cleanup_20261103_r1。AGENTS目录说明与HANDOFF第12节已更新。HEAD和main保持不变，暂存区为空；旧任务的未提交文件未动。
