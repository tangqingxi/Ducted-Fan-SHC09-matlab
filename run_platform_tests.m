function report = run_platform_tests()
% 平台契约测试与旧十四项分开列出，避免改变旧测试数量。
ca_setup();names=["test_bus","test_scheduler","test_params"];
if exist('test_plugin_conformance','file'),names(end+1)="test_plugin_conformance";end
if exist('test_topic_chain','file'),names(end+1)="test_topic_chain";end
if exist('test_topic_logger','file'),names(end+1)="test_topic_logger";end
rows={};for name=names,feval(char(name));rows(end+1,:)={char(name),true};end %#ok<AGROW>
report=cell2table(rows,'VariableNames',{'test','passed'});disp(report);
end
