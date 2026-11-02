function study=hdf_run(output_tag)
% 用户明确批准的独立正式批；不修改旧预检协议、冻结文件或控制器。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
folder=fullfile(root,'research','hover_distance_formal_20261102');addpath(folder);
assert(string(root)=="E:\Ducted-Fan-SHC09-matlab");assert(~isempty(regexp(char(output_tag),'^[A-Za-z0-9_-]+$','once')));
output=fullfile(root,'results',string(output_tag));assert(~isfolder(output),'不覆盖既有结果。');
protocol=jsondecode(fileread(fullfile(folder,'protocol.json')));methods=string(protocol.methods(:)');seeds=protocol.seeds(:)';
sources=hd_sources(root);extra=extra_sources(root,folder);
% 先核对三种子的输入及全部目标路径，再创建仅本批使用的来源锁。
input=cell(1,numel(seeds));signatures=strings(numel(seeds),1);
old=load(fullfile(root,'results','hover_distance_precheck_20261102_a1_L085_Y280_pred','logs','PCA_PREDICTIVE_s501.mat'), ...
    'cfg','model','ref','plan','signature');
for j=1:numel(seeds)
    [cfg,model,ref,plan,spec]=hd_config(seeds(j),.85,280);experiment=ppid_noise(cfg,ref,plan);
    experiment.disturbance_series=cfg.disturbance_series;signature=allocation_comparison_hash({cfg,model,ref,experiment});
    assert(cfg.duration_s==40&&spec.roll_load_fraction==.85&&spec.yaw_rate_peak_deg_s==280);
    assert(abs(spec.roll_disturbance_amplitude_nm-1.03116389557422)<1e-6);
    if seeds(j)==501
        assert(isequaln(cfg,old.cfg)&&isequaln(model,old.model)&&isequaln(ref,old.ref)&&isequaln(plan,old.plan));
        assert(string(signature)==string(old.signature),'501输入与原预检不同。');
    end
    for method=methods,assert(~isfile(fullfile(output,'logs',sprintf('%s_s%d.mat',method,seeds(j)))));end
    input{j}=struct('cfg',cfg,'model',model,'ref',ref,'plan',plan,'spec',spec,'experiment',experiment,'signature',signature);
    signatures(j)=string(signature);
end
mkdir(output);for name=["logs","failures","tracks","allocation_tracks","inputs"],mkdir(fullfile(output,name));end
diary(fullfile(output,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
copyfile(fullfile(folder,'protocol.json'),fullfile(output,'formal_protocol.json'));
copyfile(fullfile(root,'research','hover_distance','protocol.json'),fullfile(output,'scenario_protocol.json'));
copyfile(fullfile(root,'research','ppid_pindi','protocol.json'),fullfile(output,'parent_protocol.json'));
write_json(fullfile(output,'sources.json'),sources);
lock=struct('sources',sources,'formal_sources',extra,'protocol',protocol,'input_signatures',signatures, ...
    'seed501_matches_precheck',true,'source_root',root,'created_before_flight',true,'lambda_min_is_gate',false);
write_json(fullfile(output,'formal_lock.json'),lock);
write_json(fullfile(output,'request.json'),struct('stage','formal_deep_saturation','output_tag',output_tag, ...
    'roll_load_fraction',.85,'yaw_rate_peak_deg_s',280,'methods',methods,'seeds',seeds,'lambda_min_is_gate',false));
status=table();summary=table();provenance=table();
for seed=seeds,for method=methods
    status=[status;table(method,seed,"not_run","",'VariableNames',{'method','seed','status','error_id'})]; %#ok<AGROW>
end,end
writetable(status,fullfile(output,'status.csv'));
for j=1:numel(seeds)
    d=input{j};cfg=d.cfg;model=d.model;ref=d.ref;plan=d.plan;spec=d.spec;experiment=d.experiment;signature=d.signature;seed=seeds(j);
    save(fullfile(output,'inputs',sprintf('seed%d.mat',seed)),'cfg','model','ref','plan','spec','experiment','signature','-v7');
    write_json(fullfile(output,sprintf('effective_spec_s%d.json',seed)),spec);
    for method=methods
        assert(isequaln(hd_sources(root),sources)&&isequaln(extra_sources(root,folder),extra),'运行中来源发生改变。');
        row=find(status.method==method&status.seed==seed);status.status(row)="running";writetable(status,fullfile(output,'status.csv'));
        fprintf('HOVER_FORMAL_RUN %s seed%d input=%s\n',method,seed,string(signature));
        try
            L=ppid_simulate(cfg,model,ref,method,experiment,plan);
            L.ekf_rate_hz=(sum(L.estimator_updated)-1)/cfg.duration_s;L.hover_distance_spec=spec;L.actual_duration_s=cfg.duration_s;
            path=fullfile(output,'logs',sprintf('%s_s%d.mat',method,seed));save(path,'L','cfg','model','ref','plan','spec','signature','-v7');
            checks=hd_check_log(L,ref,plan);metrics=hdf_metrics(L,ref,plan,seed);save(path,'checks','metrics','-append');
            assert(metrics.valid_data&&metrics.no_divergence,'hdf:Invalid','数据或发散检查未通过，保留日志。');
            hd_write_track(output,L,ref,seed);
            trackpath=fullfile(output,'tracks',sprintf('%s_s%d.csv',method,seed));T=readtable(trackpath);keep=1:8:numel(L.time_s);
            for axis=1:3,T.("true_rate_"+axis)=rad2deg(L.omega(keep,axis));end
            writetable(T,trackpath);
            k=find(L.control_updated);A=table(L.time_s(k),L.lambda(k),L.mode(k),'VariableNames',{'time_s','lambda','mode'});
            writetable(A,fullfile(output,'allocation_tracks',sprintf('%s_s%d.csv',method,seed)));
            summary=[summary;struct2table(metrics,'AsArray',true)]; %#ok<AGROW>
            provenance=[provenance;table(method,seed,string(signature),true,'VariableNames',{'method','seed','input_signature','truth_feedback_absent'})]; %#ok<AGROW>
            status.status(row)="completed";
            fprintf('HOVER_FORMAL_DONE %s seed%d pos=%.6g roll=%.6g yaw=%.6g lambdaMin=%.6g valid=%d\n', ...
                method,seed,metrics.horizontal_rmse_m,metrics.roll_rmse_deg,metrics.yaw_rate_rmse_deg_s,metrics.normal_lambda_min,metrics.valid_data);
            clear L
        catch problem
            status.status(row)="failed";status.error_id(row)=string(problem.identifier);
            write_json(fullfile(output,'failures',sprintf('%s_s%d.json',method,seed)),struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
            fprintf('HOVER_FORMAL_FAILED %s seed%d %s\n',method,seed,problem.message);
        end
        assert(isequaln(hd_sources(root),sources)&&isequaln(extra_sources(root,folder),extra));
        writetable(status,fullfile(output,'status.csv'));writetable(summary,fullfile(output,'summary.csv'));writetable(provenance,fullfile(output,'provenance.csv'));
    end
end
write_json(fullfile(output,'completion.json'),struct('requested',15,'completed',sum(status.status=="completed"), ...
    'failed',sum(status.status=="failed"),'parameter_adjustments',0,'lambda_min_is_gate',false,'old_results_modified',false));
study=struct('output_dir',output,'status',status,'summary',summary);
end

function files=extra_sources(root,folder)
% 独立正式驱动和指标也在运行前冻结，避免原引擎不覆盖研究目录的缺口。
files=struct('path',{},'sha256',{});items=[dir(fullfile(folder,'*.m'));dir(fullfile(folder,'*.json'))];
for item=reshape(items,1,[])
    path=fullfile(item.folder,item.name);fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    files(end+1)=struct('path',string(strrep(path,[root,filesep],'')),'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
end

function write_json(path,value)
% 只写本批新目录，不覆盖旧协议、来源或正式锁。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
