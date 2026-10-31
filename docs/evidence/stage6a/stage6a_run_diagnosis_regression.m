function stage6a_run_diagnosis_regression(stage)
% 每阶段执行完整旧回归，并保留估计器真实失败，不修改原测试入口。
stage=string(stage);root=ca_setup();out=fullfile(root,'docs','estimator_diagnosis');if ~isfolder(out),mkdir(out);end
p=run_project_tests();writetable(p,fullfile(out,stage+'_project_tests.csv'));
p=run_platform_tests();writetable(p,fullfile(out,stage+'_platform_tests.csv'));
p=test_platform_baseline();writetable(p,fullfile(out,stage+'_baseline.csv'));
expected=false;
try
 run_estimator_tests();
catch problem
 assert(strcmp(problem.identifier,'shc09:LitePhysicalBias'),'非预期估计器失败：%s',problem.message);
 expected=true;failure=struct('identifier',problem.identifier,'message',problem.message);
end
assert(expected,'物理偏置门禁意外通过，必须审计。');
failure.stage=stage;failure.project_passed=14;failure.platform_passed=6;failure.baseline_exact=true;
fid=fopen(fullfile(out,stage+'_regression.json'),'w','n','UTF-8');fwrite(fid,jsonencode(failure,PrettyPrint=true),'char');fclose(fid);
end
