function study=ppid_run_study(stage,varargin)
% 开发仅用伪逆；正式运行必须已经取得完整52秒伪逆八字与独立源码锁。
root=ca_setup();stage=string(stage);assert(ismember(stage,["pilot","formal"]));
p=inputParser;addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));parse(p,varargin{:});
tag=string(p.Results.output_tag);assert(~isempty(regexp(char(tag),'^[A-Za-z0-9_-]+$','once')));
out=fullfile(root,'results','ppid_pindi_'+stage+'_'+tag);assert(~isfolder(out),'不覆盖既有新研究批次。');
[~,~,~,plan]=ppid_config(9301);manifest=ppid_source_manifest(root);
methods="EXAMPLE_PINV";seeds=plan.pilot_seed;
if stage=="formal"
    lock=jsondecode(fileread(fullfile(root,'research','ppid_pindi','formal_lock.json')));
    assert(strcmp(jsonencode(lock.sources),jsonencode(manifest)),'正式运行前源码或协议与锁不一致。');
    pilot=load(fullfile(root,lock.pilot_log),'metrics');assert(pilot.metrics.task_passed,'伪逆未完成预定任务，不启动正式比较。');
    methods=string(plan.methods(:)');seeds=plan.formal_seeds(:)';
end
mkdir(out);mkdir(fullfile(out,'logs'));mkdir(fullfile(out,'tracks'));mkdir(fullfile(out,'failures'));
copyfile(fullfile(root,'research','ppid_pindi','protocol.json'),fullfile(out,'protocol.json'));
write_json(fullfile(out,'sources.json'),manifest);
status=table();summary=table();states=table();provenance=table();
for seed=seeds,for method=methods
    status=[status;table(method,seed,"not_run","",'VariableNames',{'method','seed','status','error_id'})]; %#ok<AGROW>
end,end
writetable(status,fullfile(out,'status.csv'));
for seed=seeds
    [cfg,model,ref]=ppid_config(seed);experiment=ppid_noise(cfg,ref,plan);
    signature=allocation_comparison_hash({cfg,ref,experiment});
    for method=methods
        assert(isequaln(ppid_source_manifest(root),manifest),'批次运行中数值源码发生变化。');
        row=find(status.method==method&status.seed==seed);fprintf('PPID_RUN %s %s seed%d\n',stage,method,seed);
        try
            L=ppid_simulate(cfg,model,ref,method,experiment,plan);
            [metrics,state_rows]=ppid_evaluate(L,ref,seed,plan);
            save(fullfile(out,'logs',sprintf('%s_s%d.mat',method,seed)),'L','cfg','model','ref','plan','signature','metrics','-v7');
            ppid_write_track(out,L,ref,seed);
            summary=[summary;struct2table(metrics,'AsArray',true)];states=[states;state_rows]; %#ok<AGROW>
            provenance=[provenance;table(method,seed,signature,true,string(manifest.engine), ...
                'VariableNames',{'method','seed','input_signature','truth_feedback_absent','engine'})]; %#ok<AGROW>
            status.status(row)="completed";
            fprintf('PPID_DONE %s seed%d horizontal=%.4f yaw=%.4f task=%d elapsed=%.1fs\n', ...
                method,seed,metrics.horizontal_rmse_m,metrics.yaw_rmse_deg,metrics.task_passed,L.elapsed_s);
            clear L
        catch problem
            status.status(row)="failed";status.error_id(row)=string(problem.identifier);
            write_json(fullfile(out,'failures',sprintf('%s_s%d.json',method,seed)), ...
                struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
            fprintf('PPID_FAILED %s seed%d %s: %s\n',method,seed,problem.identifier,problem.message);
        end
        writetable(status,fullfile(out,'status.csv'));writetable(summary,fullfile(out,'summary.csv'));
        writetable(states,fullfile(out,'state_metrics.csv'));writetable(provenance,fullfile(out,'provenance.csv'));
    end
end
study=struct('output_dir',out,'status',status,'summary',summary);
write_json(fullfile(out,'completion.json'),struct('stage',stage,'completed',sum(status.status=="completed"), ...
    'failed',sum(status.status=="failed"),'requested',height(status),'old_experiments_rerun',false));
end

function write_json(path,value)
% 只写新研究目录，失败证据一并保留。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);clean=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
