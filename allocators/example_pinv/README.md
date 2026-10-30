# EXAMPLE_PINV接口示例

最小范数伪逆后逐元素裁剪；输入为统一ctx，输出6×1 rad命令与通用info。只使用名义B及边界，不预测动态，不保裁剪后的需求方向。

`example_pinv_manifest`声明能力；`registry.m`中仅增加一项，无核心方法分支。从根目录运行`ca_setup; test_plugin_conformance;`，或`main("EXAMPLE_PINV",struct('duration_s',0.2,'show_figures',false,'save_figures',false,'save_results',false));`。
