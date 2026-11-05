# C2 路径与依赖风险

基准：DEV b2a287ceff34445bb7902890141be7a450d19de9。静态虚拟替换路径完成；未移动文件。当前MATLAB路径检查PASS（287名字、六分配器、两效能插件、14句柄、重复初始化稳定），迁移后检查为NOT RUN，必须在C2实际完成后执行。

## W1映射与覆盖

[W1_RESOLVED_PLAN.csv](W1_RESOLVED_PLAN.csv)为C2执行单v1，源于历史CSV但不修改它。共81行：MOVE70（69m+1cpp）、KEEP9、DEFER_W6两份README。MOVE的70个目标均不存在，目标大小写归一后无冲突，所有父路径无文件占位。69个m目标父目录均在ca_setup显式新路径白名单中；cpp不属于MATLAB函数路径检查。

9个同源目标保留；platform/README.md与platform/modules/README.md留在原位，原目标src/runtime/README.md与src/control/README.md的占位冲突已通过DEFER_W6规避，不覆盖现有文档。CSV的target_path对DEFER写成原位路径，原计划冲突目标保存在collision_status/dependency_impact。C2执行器仅处理operation=MOVE。

## 必须随C2处理的项目

| 编号 | 风险与证据位置 | C2所需动作 |
|---|---|---|
| P1 | analysis/allocation_comparison_engine.m:3固定旧目录，69份中63份移入src会从覆盖中消失；6份接口移入allocators/interface仍被allocators递归覆盖，但其相对路径也改变 | 显式支持当前双布局白名单，逐文件证明69份仍全部进入新来源集合；登记旧ec与新engine并保留旧实现提交引用，历史锁不变 |
| P2 | tools/build_px4_ecl.py:32固定modules/state_estimator/px4_ecl/px4_ecl_bridge.cpp | 更新到新源码路径或受控双路径查找，双副本必须报错；sources[-1]参与bridge_sha256，须随之指向新文件；不运行构建，不改已有exe/build_manifest |
| P3 | tools/check_phase3_static.py拒绝D/R且默认基准为C0前main；迁移后会误报 | 改为以C1为基准验证本执行单允许的70移动、原字节及明确配套文件，拒绝其他变化；不得放宽成允许任意删除或重命名 |
| P4 | 7份源文件raw CRLF与Git blob LF不同，详见下表 | 建议在根.gitattributes末尾为7个精确目标设-text，保留raw字节入Git；不改全局m规则，不renormalize全仓；提交后逐项检查blob SHA和独立检出字节 |

以上4项尚未实施，属C2授权条件；原“只执行70条git mv”的范围不足以关闭它们。

## 七份字节保存风险

| 源路径 | raw SHA256（执行单口径） | 现Git blob内容SHA256 | 精确目标规则 |
|---|---|---|---|
| `drivers/actuators/ca_actuator_step.m` | `5ef5a93ee4ebee5ced15a1206f7982ff8270d6d1ded60069285b7351bc544535` | `468bf66d3d96c07b4c651f3f69f03a7dcfffb0cb1fbd2451181b5617a325ac90` | `/src/drivers/actuators/ca_actuator_step.m -text` |
| `drivers/actuators/ca_motor_step.m` | `ad5ec88da25332fb70aaf9d0072cf5a4aa8f9a8315a76d09e3461542645e31cf` | `d8f4da9f35e42c05b6ea755edf748845d979f916c1d871a1dbf2fd2a00bed150` | `/src/drivers/actuators/ca_motor_step.m -text` |
| `drivers/actuators/ca_pwm_timing.m` | `6d2d08e4c553b3a42240ae1efcaedcd94c862d7def879b972a52d9dad476f836` | `54d84072dcb188e697f47feca91e64e84c140c7114dbd2db9eaaf23eceff28e9` | `/src/drivers/actuators/ca_pwm_timing.m -text` |
| `lib/math/ca_euler_rotation.m` | `e7b517c57e4fc9bc19384a654cac7b64b37c96802d092e74da3291e85c157a30` | `640e11fedf37e216d465ef79e8c0c7d366091dbb0ca727a1657e25e463305377` | `/src/lib/math/ca_euler_rotation.m -text` |
| `lib/math/ca_rotation_euler.m` | `9977a3fa95b02d8f7924f049ef31a358b98a980d7368dfbc9ff013c962689ae2` | `789d222bf75254bcfb9b3d97bc84b58665b4d4a6f32dcd7d68ac31e43810db77` | `/src/lib/math/ca_rotation_euler.m -text` |
| `lib/math/ca_rotation_increment.m` | `6554a7a07b2859aa288fb962c4fab727ccfc380d7545d9d0612166ed43a40f98` | `0a05a7146449b45b2eef382741cc992d9ddc284babf81e8dc1b95b3eadba2e9f` | `/src/lib/math/ca_rotation_increment.m -text` |
| `lib/math/ca_skew.m` | `65ead5f0afe5b3a494994ac848f56d0229861b776b87e19b76a4ae83d9f28996` | `a0bf3e96350a65ede79582426a8872cb9b96e4b33d9a01e4c7091205c390225e` | `/src/lib/math/ca_skew.m -text` |

本轮全部差异仅CRLF/LF，但这仍是科学来源差异，不能以归一化放行。增加-text会让这7份文件在新路径按原raw入库，因此Git展示的blob变化必须单列为字节保存，不能谎称旧blob与新blob完全相同。其余63项也必须照执行单核验raw和发布blob。

## 调用链、内部定位与硬编码

- 平台链 main/shc09_run → platform_run → sim_driver/ca_simulate 保持函数名；PPID链 run_ppid_pindi → research/ppid_pindi 保持独立，不迁移研究控制器或改参数/时钟。W1移动的共享函数由ca_setup新路径提供。
- allocators/registry.m的六目录和算法插件保持原位；ca_allocate、ca_allocator_config、ca_allocator_name移至allocators/interface，shc09_allocator_*移至其control_allocator子目录；这些均已有显式映射。效能目录与注册表本轮不移动。
- CaPx4Ecl:13/17通过ca_setup定位根下build/px4_ecl及临时stderr；源码移动不改变exe位置。只检查which和函数/类文件，不实例化ECL，不写stderr、不重建。
- platform_run:15/23/25/27/28通过ca_setup所得根访问results、docs、build；不随源码路径改变。:31递归源码快照会记录新路径，这是新运行的身份变化；旧MAT中的路径不回写。
- shc09_write_topic_index:8的folder是调用者给定输出目录，不是mfilename父目录。69份m内部未发现依赖自身旧相对目录的load/fopen或mfilename根推导；cpp include均为第三方根包含或标准库，不依赖旧桥接目录。
- ppid_source_manifest依赖公共engine及ca_setup等显式SHA；本轮研究路径保持原位，无须提前迁移manifest函数。C2若修改engine实现，其显式SHA及engine都改变，新来源必须登记，不能把旧锁更新到新实现。
- docs/copy_manifest.json的destination、docs/matlab_references.json、tests/baseline/protected_sources.json、历史源码快照/报告含旧路径；前两者是来源/文档记录，platform_run仅加载copy_manifest作元数据。冻结baseline与历史记录保持原字节，不因现目录变化批量替换；需要新当前映射时用版本化映射。
- tools/repo_inventory.py对platform/lib/drivers路径做分类，迁移后会漏分到旧类别；不阻塞MATLAB运行，但C2证据应基于执行单而非该旧分类器，通用分类调整可留后续工具波次。

## 同名风险与边界

69份m的目标函数文件名互不重复，虚拟移动后与当前活动函数集合无额外同名冲突。ca_setup会拒绝新旧同名双副本，因此不能用复制后保留原m作为兼容方式；只保留旧目录说明，不保留活动同名实现。MATLAB旧会话缓存可能仍持有原类/句柄，迁移后用全新batch会话验证。

现有两份round5_components.m仍在docs/validation历史证据目录，不加入path，按既有精确白名单保留。禁止将tests/legacy_reference、models/shc09/reference、results、archive、冻结快照和第三方递归加入MATLAB路径。W2分配器plugins映射矛盾仍留C3前处理，C2不顺带改registry。
