function study=run_f8_pressure_study(stage,varargin)
% 有限偏航开发筛选与独立确认分开；保持原F8门槛，不按确认结果回头挑选。
root=ca_setup();stage=string(stage);assert(ismember(stage,["screen","confirm"]));p=inputParser;
addParameter(p,'scenario',"");addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
addParameter(p,'base_study',"");addParameter(p,'screen_from',"");addParameter(p,'protocol_version',1);parse(p,varargin{:});o=p.Results;
assert(ismember(o.protocol_version,[1,2]));
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
base_path=fullfile(root,'configs','f8_protocol_v1.json');pressure_path=fullfile(root,'configs',sprintf('f8_pressure_protocol_v%d.json',o.protocol_version));
base_text=fileread(base_path);pressure_text=fileread(pressure_path);plan=jsondecode(pressure_text);
ids=string({plan.candidates.id});seeds=plan.development_seeds(:)';methods=string(plan.screen_methods(:)');
if stage=="confirm"
    assert(ismember(string(o.scenario),ids));ids=string(o.scenario);seeds=plan.confirmation_seeds(:)';methods=string(plan.confirmation_methods(:)');
end
out=fullfile(root,'results','f8_pressure_'+stage+'_'+string(o.output_tag));assert(~isfolder(out),'不覆盖既有压力试验。');mkdir(out);
copyfile(base_path,fullfile(out,'base_protocol.json'));copyfile(pressure_path,fullfile(out,'frozen_protocol.json'));
engine=allocation_comparison_engine(root);all_status=table();all_summary=table();candidate_summary=table();
if stage=="screen"
    base_study=require_results_path(o.base_study,root);
    for id=["F8-R","F8-D"]
        check=jsondecode(fileread(fullfile(base_study,id,'task_evaluation.json')));
        assert(check.all_five_methods_three_seeds_completed&&check.formal_completed==15 ...
            &&~check.priority_excitation_and_nominal_geometry_requirements_met,'尚未满足启动偏航压力预案的先验条件。');
    end
    if isfield(plan,'screen_requires_base_position_scenario_all_task_passed')&&plan.screen_requires_base_position_scenario_all_task_passed
        baseline_check=jsondecode(fileread(fullfile(base_study,plan.base_position_scenario,'task_evaluation.json')));
        assert(baseline_check.all_five_methods_meet_task_requirements,'压力位置基线尚未通过全部原F8要求。');
    end
else
    screen_from=require_results_path(o.screen_from,root);selected=jsondecode(fileread(fullfile(screen_from,'selection.json')));
    assert(selected.has_promising_candidate&&string(selected.selected_scenario)==string(o.scenario),'不能绕开开发筛选选择确认轨迹。');
    screen_status=readtable(fullfile(screen_from,'status.csv'),'TextType','string');assert(height(screen_status)==9&&all(ismember(screen_status.status,["completed","failed"])));assert(sum(screen_status.scenario_id==string(o.scenario))==3&&all(screen_status.status(screen_status.scenario_id==string(o.scenario))=="completed"));
    assert(isequal(fileread(fullfile(screen_from,'base_protocol.json')),base_text) ...
        &&isequal(fileread(fullfile(screen_from,'frozen_protocol.json')),pressure_text),'开发与确认协议不一致。');
end
for id=ids
    folder=fullfile(out,id);mkdir(folder);mkdir(fullfile(folder,'logs'));mkdir(fullfile(folder,'tracks'));mkdir(fullfile(folder,'failures'));
    status=table();summary=table();states=table();provenance=table();
    for seed=seeds,for method=methods
        status=[status;table(id,method,seed,"not_run","","",'VariableNames',{'scenario_id','method','seed','status','error_id','error_message'})];
    end,end
    for seed=seeds
        [c,m,ref,protocol]=ca_f8_pressure_protocol(id,seed,o.protocol_version);protocol.smoke_test=false;protocol.stage=stage;
        protocol.development_screen=stage=="screen";protocol.seeds=seeds(:);protocol.methods=methods(:);
        write_json(fullfile(folder,'protocol.json'),protocol);experiment=ca_prepare_experiment(c,ref.time_s);
        signature=allocation_comparison_hash({c,ref,experiment});
        for method=methods
            assert(isequal(fileread(base_path),base_text)&&isequal(fileread(pressure_path),pressure_text)&&engine==allocation_comparison_engine(root));
            index=find(status.seed==seed&status.method==method);fprintf('F8_PRESSURE_RUN %s %s seed%d %s\n',stage,id,seed,method);
            try
                L=ca_simulate(m,c,ref,method,experiment);L.time_for_metrics=ref.time_s;
                assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'), ...
                    'ca:F8TruthAudit','压力试验出现真值反馈topic。');
                L=rmfield(L,'topic_log');save(fullfile(folder,'logs',sprintf('%s_s%d.mat',method,seed)),'L','c','m','ref','protocol','signature','-v7');
                [metrics,checks]=f8_evaluate_run(L,c,m,ref,protocol);
                metrics.command_step_rms_deg=sqrt(mean(diff(rad2deg(L.pwm_command_rad)).^2,'all'));
                metrics.actuator_estimate_rmse_deg=sqrt(mean(rad2deg(L.actual_delta_rad-L.estimated_delta_rad).^2,'all'));
                metrics.pwm_prediction_rmse_deg=sqrt(mean(rad2deg(L.pwm_end_prediction_error_rad(L.pwm_prediction_checked,:)).^2,'all','omitnan'));
                motion=ref.time_s>=protocol.motion_window_s(1)&ref.time_s<=protocol.motion_window_s(2);
                actual_changes=diff(rad2deg(L.actual_delta_rad(motion,:)));
                metrics.actual_servo_rate_rmse_deg_s=sqrt(mean((actual_changes*c.sample_hz).^2,'all'));
                metrics.actual_servo_total_variation_deg=sum(abs(actual_changes),'all');
                checks.priority_geometry_audited=false;checks.priority_geometry_total_scaled_s=NaN;checks.priority_geometry_longest_scaled_s=NaN;
                if startsWith(method,"PCA")
                    G=ca_priority_polytope_audit(L,m,c,ref.time_s,protocol.motion_window_s');
                    writetable(G,fullfile(folder,sprintf('priority_geometry_%s_s%d.csv',method,seed)));
                    certificate=G.static_priority_certificate;predicted=G.static_lambda_max;
                    if method=="PCA_PREDICTIVE",certificate=G.dynamic_priority_certificate;predicted=G.dynamic_lambda_max;end
                    q=ref.time_s>=6&ref.time_s<=50;normal=L.mode(q)==0;observed=L.lambda(q);
                    assert(all(isfinite(predicted(normal)))&&max(abs(predicted(normal)-observed(normal)))<1e-6,'ca:F8GeometryAudit','压力试验独立几何核对失败。');
                    active=certificate&normal&isfinite(observed)&observed<1-protocol.priority_evidence.lambda_tolerance;
                    edges=diff([false;active(:);false]);lengths=find(edges==-1)-find(edges==1);
                    checks.priority_geometry_audited=true;checks.priority_geometry_total_scaled_s=sum(active)/c.sample_hz;
                    checks.priority_geometry_longest_scaled_s=max([0;lengths])/c.sample_hz;
                end
                summary=[summary;[struct2table(metrics,'AsArray',true),struct2table(checks,'AsArray',true)]];
                states=[states;f8_write_tracking(L,ref,protocol,folder)];status.status(index)="completed";
                provenance=[provenance;table(id,method,seed,signature,protocol.frozen_protocol_hash,engine,true,false, ...
                    'VariableNames',{'scenario_id','method','seed','input_signature','frozen_protocol_hash','engine_fingerprint','truth_topics_absent','smoke_test'})];
                fprintf('F8_PRESSURE_DONE %s %s seed%d %s horizontal=%.6g yaw=%.6g task=%d scaled=%.6gs\n', ...
                    stage,id,seed,method,metrics.horizontal_position_rmse_m,metrics.yaw_rmse_deg,checks.run_task_passed,metrics.total_scaled_duration_s);
                clear L G
            catch problem
                status.status(index)="failed";status.error_id(index)=string(problem.identifier);status.error_message(index)=string(problem.message);
                write_json(fullfile(folder,'failures',sprintf('%s_s%d.json',method,seed)),struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
                fprintf('F8_PRESSURE_FAILED %s seed%d %s %s: %s\n',id,seed,method,problem.identifier,problem.message);
            end
            writetable(status,fullfile(folder,'status.csv'));writetable(summary,fullfile(folder,'task_metrics.csv'));
            writetable(states,fullfile(folder,'state_metrics.csv'));writetable(provenance,fullfile(folder,'provenance.csv'));
        end
    end
    complete=stage=="confirm"&&height(status)==15&&all(status.status=="completed")&&height(summary)==15;
    all_task=false;excitation=false;
    if complete
        all_task=all(summary.run_task_passed);
        for method=["PCA_STATIC","PCA_PREDICTIVE"]
            rows=summary(summary.method==method,:);good=rows.priority_geometry_audited ...
                &rows.priority_geometry_total_scaled_s>=protocol.priority_evidence.minimum_total_scaled_duration_s ...
                &rows.priority_geometry_longest_scaled_s>=protocol.priority_evidence.minimum_longest_scaled_episode_s;
            excitation=excitation||sum(good)>=protocol.priority_evidence.minimum_seeds_with_excitation;
        end
    end
    write_json(fullfile(folder,'task_evaluation.json'),struct('protocol_id',plan.protocol_id,'stage',stage, ...
        'formal_completed',double(stage=="confirm")*sum(status.status=="completed"),'failed',sum(status.status=="failed"), ...
        'all_five_methods_three_seeds_completed',complete,'all_five_methods_meet_task_requirements',all_task, ...
        'priority_excitation_and_nominal_geometry_requirements_met',excitation,'priority_effect_or_method_superiority_proven',false,'uses_hover_comparability_gates',false));
    if stage=="screen",candidate_summary=[candidate_summary;screen_candidate(summary,id,protocol,plan)];end
    all_status=[all_status;status];all_summary=[all_summary;summary];writetable(all_status,fullfile(out,'status.csv'));
    writetable(all_summary,fullfile(out,'task_metrics.csv'));writetable(candidate_summary,fullfile(out,'screen_candidates.csv'));
end
selection=struct('protocol_id',plan.protocol_id,'has_promising_candidate',false,'selected_scenario',"",'selection_uses_development_only',true);
if stage=="screen"&&~isempty(candidate_summary)
    eligible=candidate_summary(candidate_summary.promising,:);
    if ~isempty(eligible)
        eligible=sortrows(eligible,{'reference_peak_yaw_rate_deg_s','reference_peak_yaw_acceleration_deg_s2'});
        selection.has_promising_candidate=true;selection.selected_scenario=eligible.scenario_id(1);
    end
    write_json(fullfile(out,'selection.json'),selection);
end
study=struct('output_dir',out,'stage',stage,'status',all_status,'summary',all_summary,'selection',selection,'screen_candidates',candidate_summary);
save(fullfile(out,'study.mat'),'study','-v7');fprintf('F8_PRESSURE_COMPLETE %s completed=%d/%d failed=%d selected=%s\n', ...
    stage,sum(all_status.status=="completed"),height(all_status),sum(all_status.status=="failed"),selection.selected_scenario);
end

function result=screen_candidate(S,id,protocol,plan)
% 先验开发选择规则；不把单个开发种子的改善当成三种子确认结果。
promising=false;winner="";yaw=NaN;position=NaN;cost=NaN;rate_ratio=NaN;travel_ratio=NaN;w=S(S.method=="WLS",:);rule=plan.screen_selection;
if height(w)==1&&w.valid_data&&w.flight_envelope_passed
    for method=["PCA_STATIC","PCA_PREDICTIVE"]
        a=S(S.method==method,:);if height(a)~=1||~a.run_task_passed,continue;end
        gains=100*(w.horizontal_position_rmse_m-a.horizontal_position_rmse_m)/w.horizontal_position_rmse_m;
        yaw_gain=100*(w.yaw_rmse_deg-a.yaw_rmse_deg)/w.yaw_rmse_deg;
        no_regression=true;
        for metric=["horizontal_position_rmse_m","altitude_rmse_m","velocity_rmse_m_s","yaw_rmse_deg","inner_attitude_rmse_deg","estimator_attitude_rmse_deg"]
            no_regression=no_regression&&a.(metric)<=w.(metric)*(1+rule.maximum_regression_in_other_tracking_RMS_percent/100);
        end
        ratio=a.command_step_rms_deg/max(w.command_step_rms_deg,1e-12);
        physical_rate_ratio=a.actual_servo_rate_rmse_deg_s/max(w.actual_servo_rate_rmse_deg_s,1e-12);
        physical_travel_ratio=a.actual_servo_total_variation_deg/max(w.actual_servo_total_variation_deg,1e-12);
        better=(~w.run_task_passed&&rule.allow_PCA_task_pass_when_WLS_task_fails) ...
            ||(max(gains,yaw_gain)>=rule.minimum_improvement_in_horizontal_or_yaw_RMS_percent&&no_regression);
        if isfield(rule,'maximum_whole_run_PWM_step_RMS_ratio_to_WLS')
            cost_passed=ratio<=rule.maximum_whole_run_PWM_step_RMS_ratio_to_WLS;
        else
            cost_passed=physical_rate_ratio<=rule.maximum_main_window_actual_servo_rate_RMS_ratio_to_WLS ...
                &&physical_travel_ratio<=rule.maximum_main_window_actual_servo_travel_ratio_to_WLS;
        end
        if better&&cost_passed
            promising=true;winner=method;yaw=yaw_gain;position=gains;cost=ratio;rate_ratio=physical_rate_ratio;travel_ratio=physical_travel_ratio;break;
        end
    end
end
x=protocol.reference_preflight_result;result=table(id,promising,winner,position,yaw,cost,rate_ratio,travel_ratio,x.peak_yaw_rate_deg_s,x.peak_yaw_acceleration_deg_s2, ...
    'VariableNames',{'scenario_id','promising','candidate_method','horizontal_RMS_improvement_percent','yaw_RMS_improvement_percent','PWM_step_ratio','actual_servo_rate_ratio','actual_servo_travel_ratio', ...
    'reference_peak_yaw_rate_deg_s','reference_peak_yaw_acceleration_deg_s2'});
end

function write_json(path,value)
% 逐次落盘并保留全部失败，不覆盖已有输出目录。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end

function path=require_results_path(value,root)
% 只接受本仓库结果目录中的已完成研究，不访问外部工程。
assert(strlength(string(value))>0,'必须提供先验条件研究目录。');file=java.io.File(char(value));
if ~file.isAbsolute(),file=java.io.File(root,char(value));end
path=string(file.getCanonicalPath());allowed_file=java.io.File(fullfile(root,'results'));allowed=string(allowed_file.getCanonicalPath())+filesep;
assert(startsWith(lower(path),lower(allowed)),'研究目录必须在当前仓库results内。');
end
