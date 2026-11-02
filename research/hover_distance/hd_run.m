function study=hd_run(stage,varargin)
% 预检只准501；正式批须同设置伪逆和预测PCA通过后独立锁定，禁止覆盖输出。
root=ca_setup();stage=string(stage);assert(ismember(stage,["precheck","formal"]));
p=inputParser;addParameter(p,'method',"EXAMPLE_PINV");addParameter(p,'load_fraction',.85);addParameter(p,'yaw_rate_deg_s',280);
addParameter(p,'reason',"Initial user-specified precheck");addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));parse(p,varargin{:});o=p.Results;
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
output=fullfile(root,'results','hover_distance_'+stage+'_'+string(o.output_tag));assert(~isfolder(output),'不覆盖既有结果。');
manifest=hd_sources(root);methods=string(o.method);seeds=501;fraction=o.load_fraction;peak=o.yaw_rate_deg_s;
assert(stage=="formal"||ismember(methods,["EXAMPLE_PINV","PCA_PREDICTIVE"]));
if stage=="formal"
    lock=jsondecode(fileread(fullfile(root,'research','hover_distance','formal_lock.json')));
    assert(strcmp(jsonencode(lock.sources),jsonencode(manifest)),'正式来源与独立锁不符。');
    fraction=lock.roll_load_fraction;peak=lock.yaw_rate_peak_deg_s;
    for parent=string(lock.precheck_folders(:)')
        previous=readtable(fullfile(root,parent,'summary.csv'));assert(height(previous)==1&&previous.precheck_passed);
    end
    methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];seeds=[501,502,503];
end
mkdir(output);mkdir(fullfile(output,'logs'));mkdir(fullfile(output,'failures'));mkdir(fullfile(output,'tracks'));
diary(fullfile(output,'run.log'));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
write_json(fullfile(output,'sources.json'),manifest);
write_json(fullfile(output,'request.json'),struct('stage',stage,'load_fraction',fraction,'yaw_rate_peak_deg_s',peak,'reason',o.reason));
copyfile(fullfile(root,'research','hover_distance','protocol.json'),fullfile(output,'scenario_protocol.json'));
copyfile(fullfile(root,'research','ppid_pindi','protocol.json'),fullfile(output,'parent_protocol.json'));
status=table();summary=table();provenance=table();
for seed=seeds,for method=methods
    status=[status;table(method,seed,"not_run","",'VariableNames',{'method','seed','status','error_id'})]; %#ok<AGROW>
end,end
writetable(status,fullfile(output,'status.csv'));
for seed=seeds
    [cfg,model,ref,plan,spec]=hd_config(seed,fraction,peak);experiment=ppid_noise(cfg,ref,plan);
    experiment.disturbance_series=cfg.disturbance_series;signature=allocation_comparison_hash({cfg,model,ref,experiment});
    write_json(fullfile(output,sprintf('effective_spec_s%d.json',seed)),spec);
    fprintf('HOVER_AUTHORITY seed%d axes_Nm=%s roll_amplitude=%.9gNm fraction=%.2f yaw=%.0fdeg_s\n',seed,mat2str(spec.axis_capacity_nm',8),spec.roll_disturbance_amplitude_nm,fraction,peak);
    for method=methods
        assert(strcmp(jsonencode(hd_sources(root)),jsonencode(manifest)),'运行中数值源码发生改变。');
        row=find(status.method==method&status.seed==seed);status.status(row)="running";writetable(status,fullfile(output,'status.csv'));
        fprintf('HOVER_RUN %s %s seed%d\n',stage,method,seed);
        try
            L=ppid_simulate(cfg,model,ref,method,experiment,plan);
            % 父仿真器仅此统计元数据硬编码52秒；40秒场景在包装层修正，不改控制或时钟。
            L.ekf_rate_hz=(sum(L.estimator_updated)-1)/cfg.duration_s;
            L.hover_distance_spec=spec;L.actual_duration_s=cfg.duration_s;
            log_path=fullfile(output,'logs',sprintf('%s_s%d.mat',method,seed));
            save(log_path,'L','cfg','model','ref','plan','spec','signature','-v7');
            metrics=hd_metrics(L,ref,plan,seed);checks=hd_check_log(L,ref,plan);
            save(log_path,'metrics','checks','-append');
            hd_write_track(output,L,ref,seed);
            summary=[summary;struct2table(metrics,'AsArray',true)]; %#ok<AGROW>
            provenance=[provenance;table(method,seed,signature,true,'VariableNames',{'method','seed','input_signature','truth_feedback_absent'})]; %#ok<AGROW>
            status.status(row)="completed";
            fprintf('HOVER_DONE %s seed%d valid=%d healthy=%d precheck=%d horiz=%.4f roll=%.3f yawrate=%.3f duty=%.4f min=%.4f mode1=%.4f mode2=%.4f\n', ...
                method,seed,metrics.valid_data,metrics.hover_healthy,metrics.precheck_passed,metrics.horizontal_rmse_m,metrics.roll_rmse_deg,metrics.yaw_rate_rmse_deg_s,metrics.lambda_scaled_duty,metrics.normal_lambda_min,metrics.mode1_duty,metrics.mode2_duty);
            clear L
        catch problem
            status.status(row)="failed";status.error_id(row)=string(problem.identifier);
            write_json(fullfile(output,'failures',sprintf('%s_s%d.json',method,seed)), ...
                struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
            fprintf('HOVER_FAILED %s seed%d %s: %s\n',method,seed,problem.identifier,problem.message);
        end
        assert(strcmp(jsonencode(hd_sources(root)),jsonencode(manifest)),'运行结束时源码与快照不符。');
        writetable(status,fullfile(output,'status.csv'));writetable(summary,fullfile(output,'summary.csv'));writetable(provenance,fullfile(output,'provenance.csv'));
    end
end
study=struct('output_dir',output,'status',status,'summary',summary);
write_json(fullfile(output,'completion.json'),struct('stage',stage,'requested',height(status),'completed',sum(status.status=="completed"),'failed',sum(status.status=="failed"),'old_results_rerun',false));
end

function write_json(path,value)
% 所有记录只写本次新建目录。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
