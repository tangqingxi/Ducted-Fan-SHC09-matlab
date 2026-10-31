function [report,details] = run_estimator_tests()
% 估计器真实化测试独立运行，不改变旧十四项及平台六项计数。
ca_setup();names=["test_sensor_model","test_estimator_lite_attitude","test_estimator_isolation","test_estimator_lite_position"];
details=struct();rows={};for name=names
 assert(exist(name,'file')==2,'缺少估计器测试：%s',name);if nargout(char(name))>0,details.(name)=feval(char(name));else,feval(char(name));details.(name)=struct('passed',true);end;rows(end+1,:)={char(name),true};
end
report=cell2table(rows,'VariableNames',{'test','passed'});disp(report);
end
