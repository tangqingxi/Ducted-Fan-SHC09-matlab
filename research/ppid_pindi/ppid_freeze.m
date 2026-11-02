function lock=ppid_freeze(pilot_folder)
% 开发验收后一次性写正式锁；不覆盖旧锁，也不将正式结果用于整定公共控制器。
root=ca_setup();path=fullfile(root,'research','ppid_pindi','formal_lock.json');assert(~isfile(path),'正式锁已存在，不允许覆盖。');
status=readtable(fullfile(pilot_folder,'status.csv'),'TextType','string');assert(height(status)==1&&status.status=="completed"&&status.method=="EXAMPLE_PINV");
log_path=fullfile(pilot_folder,'logs',sprintf('EXAMPLE_PINV_s%d.mat',status.seed));data=load(log_path,'metrics','plan');
assert(data.metrics.task_passed,'伪逆开发未达到预先声明的宽松任务要求。');
assert(isfile(fullfile(pilot_folder,'independent_checks.json')),'先完成独立后处理核验再写正式锁。');
% 开发后只补强驱动与锁覆盖；控制、传感器、对象与协议必须仍与通过的开发运行相同。
before=jsondecode(fileread(fullfile(pilot_folder,'sources.json')));current=ppid_source_manifest(root);
assert(strcmp(before.engine,current.engine));
administrative=["ppid_source_manifest.m","ppid_run_study.m","ppid_freeze.m"];
for item=reshape(before.files,1,[])
    [~,name,extension]=fileparts(item.path);
    if ismember(string(name)+extension,administrative),continue;end
    observed=current.files(string({current.files.path})==string(item.path));
    assert(isscalar(observed)&&strcmp(item.sha256,observed.sha256),'开发后数值源码发生变化，不能直接冻结。');
end
lock=struct('sources',ppid_source_manifest(root),'pilot_log',string(strrep(log_path,[root,filesep],'')), ...
    'pilot_seed',status.seed,'controller_tuned_with_pseudoinverse_only',true,'formal_runs_started',false);
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(lock,PrettyPrint=true));
end
