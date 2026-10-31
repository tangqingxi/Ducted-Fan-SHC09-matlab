function report = check_repo_hygiene()
% 检查当前索引覆盖、活跃同名冲突、文档链接、大文件与临时文件；候选不删除。
root=ca_setup();script=fullfile(root,'tools','repo_inventory.py');
[status,output]=system(sprintf('python "%s" --check',script));fprintf('%s',output);assert(status==0,'shc09:Hygiene','仓库治理检查失败。');
report=jsondecode(fileread(fullfile(root,'docs','repo_hygiene_checks.json')));
collisions=jsondecode(fileread(fullfile(root,'docs','function_collisions.json')));
for k=1:numel(collisions)
 if numel(collisions(k).active_paths)>1,error('shc09:FunctionConflict','活跃函数重名：%s',collisions(k).name);end
end
assert(report.passed);fprintf('仓库治理检查通过；未引用候选保留待审。\n');
end
