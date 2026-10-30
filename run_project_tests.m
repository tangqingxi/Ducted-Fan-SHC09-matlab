function report = run_project_tests(include_navigation,test_names)
% 在当前仓库内执行测试；导航测试需要先编译可选ECL桥接。
if nargin<1, include_navigation=false; end
root=ca_setup();
names=["test_shc09_physics","test_comparison","test_sensor_chain", ...
    "test_benchmark_organization","test_position_attitude_yaw","test_ws_gnc_hover", ...
    "test_priority_direction_study","test_priority_pilot","test_minimum_change_restore", ...
    "test_candidate_protocol","test_vane_mismatch","test_low_speed_aero", ...
    "test_mismatch_protocol","test_mismatch_runner"];
if include_navigation, names(end+1)="test_realistic_navigation"; end
if nargin>=2
    test_names=reshape(string(test_names),1,[]);
    assert(~isempty(test_names) && all(ismember(test_names,names)),'未知项目测试。');
    names=test_names;
end
rows={};
for name=names
    fprintf('项目测试：%s\n',name);started=tic;
    feval(char(name));
    rows(end+1,:)={char(name),true,toc(started)}; %#ok<AGROW>
end
report=cell2table(rows,'VariableNames',{'test','passed','elapsed_s'});
folder=fullfile(root,'results','validation');if ~isfolder(folder),mkdir(folder);end
writetable(report,fullfile(folder,'project_tests.csv'),'Encoding','UTF-8');
fprintf('全部%d项项目测试通过。\n',height(report));
end
