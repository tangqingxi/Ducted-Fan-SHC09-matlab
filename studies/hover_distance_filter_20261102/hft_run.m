function study=hft_run(stage,output_tag,configurations)
% 仅允许六组粗扫或两组复核；本入口不具备启动五方法正式批的分支。
root=ca_setup();addpath(fullfile(root,'studies','ppid_pindi'));addpath(fullfile(root,'studies','hover_distance'));
addpath(fullfile(root,'studies','hover_distance_formal_20261102'));folder=fullfile(root,'studies','hover_distance_filter_20261102');addpath(folder);
protocol_path=fullfile(root,'research','hover_distance_filter_20261102','protocol.json');p=jsondecode(fileread(protocol_path));stage=string(stage);assert(ismember(stage,["coarse","review"]));
if stage=="coarse",seeds=501;configurations=p.configuration_order_hz;
else,seeds=[502,503];assert(isequal(size(configurations),[2,2])&&all(ismember(configurations,p.configuration_order_hz,'rows')));end
assert(~isempty(regexp(char(output_tag),'^[A-Za-z0-9_-]+$','once')));output=fullfile(root,'results',string(output_tag));
assert(~isfolder(output),'不覆盖既有目录。');sources=hft_sources(root);methods=string(p.methods(:)');
mkdir(output);mkdir(fullfile(output,'logs'));mkdir(fullfile(output,'inputs'));mkdir(fullfile(output,'failures'));
copyfile(protocol_path,fullfile(output,'tuning_protocol.json'));write_json(fullfile(output,'sources.json'),sources);
write_json(fullfile(output,'request.json'),struct('stage',stage,'configurations',configurations,'seeds',seeds,'methods',methods));
write_json(fullfile(output,'source_lock.json'),struct('sources',sources,'created_before_flight',true));
diary(fullfile(output,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
status=table();summary=table();provenance=table();
for j=1:size(configurations,1),for seed=seeds,for method=methods
    status=[status;table(configurations(j,1),configurations(j,2),method,seed,"not_run","", ...
        'VariableNames',{'h1_hz','h2_hz','method','seed','status','error_id'})]; %#ok<AGROW>
end,end,end
writetable(status,fullfile(output,'status.csv'));
% 全部输入在首条飞行之前构造并锁定，核对除两项滤波以外与标称批完全相同。
input=cell(size(configurations,1),numel(seeds));
for j=1:size(configurations,1),for k=1:numel(seeds)
    seed=seeds(k);h1=configurations(j,1);h2=configurations(j,2);[cfg,model,ref,plan,spec]=hd_config(seed,.85,280);
    baseline=load(fullfile(root,'results','hover_distance_formal_20261102_r1','inputs',sprintf('seed%d.mat',seed)));
    assert(isequaln(cfg,baseline.cfg)&&isequaln(model,baseline.model)&&isequaln(ref,baseline.ref)&&isequaln(plan,baseline.plan));
    plan.controller.indi_output_filter_hz=h1;plan.controller.indi_input_filter_hz=h2;
    restore=plan;restore.controller.indi_output_filter_hz=baseline.plan.controller.indi_output_filter_hz;
    restore.controller.indi_input_filter_hz=baseline.plan.controller.indi_input_filter_hz;assert(isequaln(restore,baseline.plan));
    experiment=ppid_noise(cfg,ref,plan);experiment.disturbance_series=cfg.disturbance_series;
    assert(isequaln(experiment,baseline.experiment));
    signature=allocation_comparison_hash({cfg,model,ref,experiment,plan});
    numerical_input_signature=allocation_comparison_hash({cfg,model,ref,experiment});assert(string(numerical_input_signature)==string(baseline.signature));
    input{j,k}=struct('cfg',cfg,'model',model,'ref',ref,'plan',plan,'spec',spec,'experiment',experiment,'signature',signature);
    save(fullfile(output,'inputs',sprintf('H%02d_%02d_s%d.mat',h1,h2,seed)),'cfg','model','ref','plan','spec','signature','numerical_input_signature','-v7');
end,end
write_json(fullfile(output,'inputs_locked.json'),struct('all_inputs_fixed_before_flight',true,'only_two_filter_fields_differ',true));
for j=1:size(configurations,1),for k=1:numel(seeds)
    d=input{j,k};cfg=d.cfg;model=d.model;ref=d.ref;plan=d.plan;spec=d.spec;experiment=d.experiment;signature=d.signature;
    seed=seeds(k);h1=configurations(j,1);h2=configurations(j,2);
    for method=methods
        assert(isequaln(hft_sources(root),sources),'研究来源发生改变。');
        row=find(status.h1_hz==h1&status.h2_hz==h2&status.seed==seed&status.method==method);
        status.status(row)="running";writetable(status,fullfile(output,'status.csv'));
        fprintf('FILTER_RUN %s H%d_H%d %s seed%d\n',stage,h1,h2,method,seed);
        try
            L=ppid_simulate(cfg,model,ref,method,experiment,plan);L.ekf_rate_hz=(sum(L.estimator_updated)-1)/40;
            L.hover_distance_spec=spec;L.actual_duration_s=40;
            path=fullfile(output,'logs',sprintf('H%02d_%02d_%s_s%d.mat',h1,h2,method,seed));
            save(path,'L','cfg','model','ref','plan','spec','signature','-v7');
            checks=hd_check_log(L,ref,plan);metrics=hft_metrics(L,cfg,model,ref,plan,seed,h1,h2);
            save(path,'checks','metrics','-append');assert(metrics.valid_data&&metrics.no_divergence);
            summary=[summary;struct2table(metrics,'AsArray',true)]; %#ok<AGROW>
            provenance=[provenance;table(h1,h2,method,seed,string(signature), ...
                'VariableNames',{'h1_hz','h2_hz','method','seed','input_signature_including_plan'})]; %#ok<AGROW>
            status.status(row)="completed";
            fprintf('FILTER_DONE H%d_H%d %s seed%d roll_residual=%.6f%% vector_residual=%.6f%%\n',h1,h2,method,seed,100*metrics.residual_roll_ratio,100*metrics.residual_vector_ratio);
            clear L
        catch problem
            status.status(row)="failed";status.error_id(row)=string(problem.identifier);
            write_json(fullfile(output,'failures',sprintf('H%02d_%02d_%s_s%d.json',h1,h2,method,seed)), ...
                struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
            fprintf('FILTER_FAILED H%d_H%d %s seed%d %s\n',h1,h2,method,seed,problem.message);
        end
        assert(isequaln(hft_sources(root),sources));writetable(status,fullfile(output,'status.csv'));
        writetable(summary,fullfile(output,'tuning.csv'));writetable(provenance,fullfile(output,'provenance.csv'));
    end
end,end
write_json(fullfile(output,'completion.json'),struct('requested',height(status),'completed',sum(status.status=="completed"), ...
    'failed',sum(status.status=="failed"),'formal_15_runs_launched',false));
study=struct('output_dir',output,'status',status,'summary',summary);
end

function write_json(path,value)
% 只写本次全新目录，不修改标称批、旧协议或锁。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
