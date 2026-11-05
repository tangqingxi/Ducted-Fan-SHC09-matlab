function study = run_mismatch_ladder(overrides)
% 六档对象失配逐方法检查点；普通失败继续，高速气动越界整体停止。
if nargin<1, overrides=struct(); end
root=ca_setup();
options=struct('output_tag',char("mismatch_ladder_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))), ...
    'duration_s',20,'load_fraction',0.6,'protocol_mode',"load_hold", ...
    'case_ids',["M0","M1","M2","M2b","M3","M4"],'fail_fast',false, ...
    'methods',["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"], ...
    'wls_axis_weights',[1;1;1000],'aero_low_speed_model',"hold_90");
for name=reshape(string(fieldnames(overrides)),1,[])
    assert(isfield(options,name),'未知结构失配实验选项：%s',name); options.(name)=overrides.(name);
end
assert(~isempty(regexp(options.output_tag,'^mismatch_ladder_[A-Za-z0-9_-]+$','once')),'输出标签须以mismatch_ladder_开头。');
assert(isscalar(options.fail_fast) && ismember(options.fail_fast,[0,1]),'快速失败标志错误。');
[cfg,model,ref,experiment,protocol,all_cases]=ca_mismatch_protocol(options.duration_s,options.load_fraction,options.protocol_mode);
cfg.methods=reshape(string(options.methods),1,[]); cfg.wls_axis_weights=options.wls_axis_weights;
cfg.aero_low_speed_model=string(options.aero_low_speed_model); cfg=ca_validate_config(cfg);
protocol.wls_axis_weights=cfg.wls_axis_weights;
ids=reshape(string(options.case_ids),1,[]);
assert(~isempty(ids) && numel(unique(ids))==numel(ids) && all(ismember(ids,string({all_cases.id}))),'工况编号重复或未知。');
cases=all_cases(ismember(string({all_cases.id}),ids));
out=fullfile(root,'results',options.output_tag); assert(~isfolder(out),'结果目录已存在，禁止覆盖。'); mkdir(out);
study=struct('output_dir',out,'options',options,'protocol',protocol,'config',cfg,'model',model, ...
    'summary',table(),'status',table(),'completed',false,'finished',false,'stopped',false,'stop_reason',"");
definitions=ca_mismatch_cases(cases,model,protocol);
writetable(definitions,fullfile(out,'cases.csv'),'Encoding','UTF-8');
save(fullfile(out,'inputs.mat'),'cfg','model','ref','experiment','protocol','options','cases','-v7');
sources=dir(fullfile(root,'**','*.m'));
sources=sources(~contains(string({sources.folder}),string(filesep)+["results","reference","third_party"]));
implementation=cell(numel(sources),2);
for k=1:numel(sources)
    source=fullfile(sources(k).folder,sources(k).name);
    implementation{k,1}=erase(source,[root,filesep]); implementation{k,2}=fileread(source);
end
environment=struct('matlab',version,'created_at',char(datetime('now')));
save(fullfile(out,'provenance.mat'),'implementation','environment','-v7');
nominal=ca_allocator_config(cfg); statuses={};
for item=cases
    trial=cfg; trial.vane_gain_scale=item.gains; trial.vane_deflection_map=string(item.mapping);
    trial.vane_saturation_deg=item.saturation_deg; trial=ca_validate_config(trial);
    assert(isequaln(ca_allocator_config(trial),nominal) && isequaln(ca_model(trial),model), ...
        'ca:TruthLeak','对象参数改变了分配器可见的配置或模型。');
    folder=fullfile(out,item.id); mkdir(folder);
    save(fullfile(folder,'inputs.mat'),'trial','model','ref','experiment','protocol','-v7');
    for method=cfg.methods
        fprintf('结构失配 %s/%s，负载%.0f%%，低速模型%s。\n',item.id,method,100*options.load_fraction,cfg.aero_low_speed_model);
        started=tic; method_dir=fullfile(folder,char(method)); mkdir(method_dir);
        try
            log=ca_simulate(model,trial,ref,method,experiment);
            assert(~any(log.table_extrapolated),'ca:AeroTableDomain','控制采样存在气动表越界。');
            log.time_for_metrics=ref.time_s;
            save(fullfile(method_dir,'log.mat'),'log','trial','-v7'); ca_write_logs(log,ref,method_dir);
            study.summary=[study.summary;ca_mismatch_metrics(log,model,item.id,"whole",[0,trial.duration_s]); ...
                ca_mismatch_metrics(log,model,item.id,"task",protocol.evaluation_window_s)];
            statuses(end+1,:)={item.id,char(method),'completed','','',toc(started),false,NaN}; %#ok<AGROW>
        catch problem
            [stop,high_speed_gate,airspeed]=ca_mismatch_should_stop(problem,trial,options.fail_fast);
            failure=struct('case_id',item.id,'method',method,'identifier',problem.identifier, ...
                'message',problem.message,'stack',problem.stack,'high_speed_gate',high_speed_gate,'airspeed_m_s',airspeed);
            save(fullfile(method_dir,'failure.mat'),'failure','trial','-v7');
            statuses(end+1,:)={item.id,char(method),'failed',problem.identifier,problem.message,toc(started),high_speed_gate,airspeed}; %#ok<AGROW>
            if stop
                study.stopped=true; study.stop_reason=string(problem.message);
                checkpoint(); ca_mismatch_report(study); fprintf('整体停止：%s\n',problem.message); return;
            end
            fprintf('已记录失败，继续预定计划：%s\n',problem.message);
        end
        checkpoint();
    end
end
study.finished=true; study.completed=all(string(study.status.status)=="completed");
checkpoint(); ca_mismatch_report(study);
fprintf('本次计划保存至：%s\n',out);
    function checkpoint()
        % 汇总只包含完整运行，失败与未运行项另列，不把缺失值补零。
        study.status=cell2table(statuses,'VariableNames',{'case_id','method','status','error_id','error_message','elapsed_s','high_speed_gate','failure_airspeed_m_s'});
        writetable(study.status,fullfile(out,'status.csv'),'Encoding','UTF-8');
        if ~isempty(study.summary), writetable(study.summary,fullfile(out,'summary.csv'),'Encoding','UTF-8'); end
        save(fullfile(out,'study.mat'),'study','-v7');
    end
end
