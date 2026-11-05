function report = check_phase3_paths(root)
% 在隔离会话中调用；只检查解析与来源，不运行仿真或保存永久路径。
if nargin<1, root=fileparts(fileparts(mfilename('fullpath'))); end
original=path; cleanup=onCleanup(@()path(original));
addpath(root); root=ca_setup;
first=path; ca_setup; assert(strcmp(first,path),'重复初始化改变搜索路径。');
% 四环链原入口会显式添加此目录，此处只重现其路径上下文。
research=fullfile(root,'research','ppid_pindi');
if isfolder(research), addpath(research); else, addpath(fullfile(root,'studies','ppid_pindi')); end
required={'ca_setup','main','shc09_run','platform_run','run_ppid_pindi','registry', ...
    'effectiveness_registry','ca_allocate','allocation_comparison_engine','ppid_source_manifest', ...
    'shc09_airframe','ca_model','ca_plant_init','ca_plant_step','ca_shc09_aerodynamics','da_ns_allocate','wls_allocate','dca_allocate', ...
    'pca_static_allocate','pca_predictive_allocate','ppid_control_step','ppid_simulate'};
% 对全部显式路径内的直属实现执行 which -all。
directories=strsplit(path,pathsep); names=required;
for k=1:numel(directories)
    if startsWith(lower(strrep(directories{k},'\','/')),lower(strrep([root,filesep],'\','/')))
        files=dir(fullfile(directories{k},'*.m'));
        for item=reshape(files,1,[]), [~,name]=fileparts(item.name); names{end+1}=name; end %#ok<AGROW>
    end
end
names=unique(names,'stable'); checks=struct('name',{},'resolved',{},'all',{});
for k=1:numel(names)
    name=names{k}; resolved=which(name); candidates=which(name,'-all');
    if ischar(candidates), candidates=cellstr(candidates); end
    assert(~isempty(resolved),'函数无法解析：%s',name);
    normalized=strrep(resolved,'\','/');
    assert(startsWith(lower(normalized),lower(strrep([root,filesep],'\','/'))),'函数解析到仓库外：%s',name);
    assert(isempty(regexp(normalized,'/(results|archive|docs/validation|reference)/','once')),'解析到冻结或结果目录。');
    assert(numel(candidates)==1,'存在未经解释的同名候选：%s',name);
    checks(end+1)=struct('name',name,'resolved',resolved,'all',{candidates}); %#ok<AGROW>
end
plugins=registry(); assert(numel(plugins)==6);
handles=struct('name',{},'file',{});
for plugin=plugins
    assert(isfolder(fullfile(root,plugin.directory)));
    for field={'allocate','manifest'}
        handle=plugin.(field{1}); info=functions(handle);
        assert(isfile(info.file) && strcmpi(info.file,which(func2str(handle))));
        handles(end+1)=struct('name',func2str(handle),'file',info.file); %#ok<AGROW>
    end
end
effects=effectiveness_registry();
for effect=effects
    assert(isfolder(fullfile(root,effect.directory)) || isfolder(fullfile(root,'src',effect.directory)));
    info=functions(effect.factory); assert(isfile(info.file) && strcmpi(info.file,which(func2str(effect.factory))));
    handles(end+1)=struct('name',func2str(effect.factory),'file',info.file); %#ok<AGROW>
end
report=struct('status','PASS','matlab',version,'idempotent',true,'checks',checks, ...
    'handles',handles,'allocator_count',numel(plugins),'effect_count',numel(effects), ...
    'source_manifest',ppid_source_manifest(root));
end
