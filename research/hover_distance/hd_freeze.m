function lock=hd_freeze(pinv_folder,predictive_folder)
% 只有同设置的伪逆与预测PCA预检全部通过才创建新锁，旧锁不改。
root=ca_setup();path=fullfile(root,'research','hover_distance','formal_lock.json');assert(~isfile(path));
a=readtable(fullfile(pinv_folder,'summary.csv'),'TextType','string');b=readtable(fullfile(predictive_folder,'summary.csv'),'TextType','string');
assert(height(a)==1&&height(b)==1&&a.method=="EXAMPLE_PINV"&&b.method=="PCA_PREDICTIVE"&&a.seed==501&&b.seed==501);
assert(a.precheck_passed&&b.precheck_passed,'预检未达要求，禁止启动正式批。');
ia=readtable(fullfile(pinv_folder,'provenance.csv'),'TextType','string');ib=readtable(fullfile(predictive_folder,'provenance.csv'),'TextType','string');assert(ia.input_signature==ib.input_signature);
sources=hd_sources(root);
for folder=[string(pinv_folder),string(predictive_folder)]
    previous=jsondecode(fileread(fullfile(folder,'sources.json')));assert(strcmp(jsonencode(previous),jsonencode(sources)));
end
request=jsondecode(fileread(fullfile(predictive_folder,'request.json')));
lock=struct('sources',sources,'roll_load_fraction',request.load_fraction,'yaw_rate_peak_deg_s',request.yaw_rate_peak_deg_s, ...
    'precheck_folders',string({strrep(char(pinv_folder),[root,filesep],''),strrep(char(predictive_folder),[root,filesep],'')}), ...
    'formal_seeds',[501,502,503],'development_seed_in_formal_batch',true);
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(lock,PrettyPrint=true));
end
