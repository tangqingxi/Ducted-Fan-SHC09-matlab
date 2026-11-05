function study = run_figure8_search(stage,varargin)
% 动态任务只作描述性比较；悬停门禁另存对照，不据此筛选轨迹或方法。
root=ca_setup();stage=string(stage);assert(ismember(stage,["screen","confirm"]));p=inputParser;
addParameter(p,'scenario',"");addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
addParameter(p,'candidates',strings(1,0));addParameter(p,'design_note',"首轮预定六候选；候选扩展必须另写适应性设计说明");
addParameter(p,'velocity_aiding',false);
parse(p,varargin{:});o=p.Results;assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
catalog=ca_figure8_search_protocol();ids=string({catalog.id});
if stage=="screen"
    requested=reshape(string(o.candidates),1,[]);
    if isempty(requested),ids=ids(1:6);else,assert(all(ismember(requested,ids))&&numel(unique(requested))==numel(requested));ids=requested;end
end
if stage=="confirm",assert(ismember(string(o.scenario),ids));ids=string(o.scenario);end
seeds=2;methods="WLS";
if stage=="confirm",seeds=1:3;methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];end
out=fullfile(root,'results','figure8_search_'+stage+'_'+string(o.output_tag));assert(~isfolder(out),'不覆盖既有搜索目录。');mkdir(out);
rules=struct('stage',stage,'candidate_catalog',catalog,'requested_candidates',ids,'design_note',string(o.design_note),'seeds',seeds,'methods',methods, ...
    'evaluation_policy',"trajectory_descriptive_v2", ...
    'lite_velocity_aiding_enabled',logical(o.velocity_aiding), ...
    'true_tau_ms',[24,27,30,33,36,40],'estimator_tau_ms',30,'actuator_calibrated',false, ...
    'max_attitude_peak_deg',5,'max_saturation_percent',10,'max_lite_attitude_rmse_deg',2,'aero_extrapolation_count',0, ...
    'position_nrmse_max',0.75,'nonzero_yaw_nrmse_max',0.35,'zero_yaw_rmse_max_deg',2, ...
    'selection_rule',"不按悬停门禁或方法胜负自动挑轨迹；轨迹激励和方法比较分别报告，暂无经独立依据确定的动态任务验收阈值", ...
    'threshold_role',"本文件数值阈值均为已废弃筛选方案的历史对照，不决定动态轨迹比较资格", ...
    'screen_role',"已知较差种子2的WLS预筛，不构成五方法可比资格或独立验证", ...
    'priority_geometry_role',"使用当前闭环记录输入的名义冻结集合，主窗排除启动；单独报告，不能冒充真实对象可达性证明");
write_json(fullfile(out,'predefined_search_rules.json'),rules);
all_summary=table();all_states=table();all_status=table();quality=table();
for id=ids
    folder=fullfile(out,id);mkdir(folder);mkdir(fullfile(folder,'logs'));mkdir(fullfile(folder,'tracks'));mkdir(fullfile(folder,'failures'));
    S=table();states=table();plan=table();provenance=table();
    for seed=seeds,for method=methods
        plan=[plan;table("M2b_"+id+"_servo_mismatch",0.6,"lite",seed,method,false,"not_run","","",false, ...
            'VariableNames',{'case_id','load_fraction','estimator_mode','seed','method','smoke_test','status','error_id','error_message','aero_extrapolated'})];
    end,end
    for si=1:numel(seeds)
        [c,model,ref,protocol]=ca_figure8_search_protocol(id,seeds(si),o.velocity_aiding);
        protocol.stage=stage;protocol.seed_list=seeds;protocol.methods=methods;
        protocol.evaluation_policy=rules.evaluation_policy;
        protocol.legacy_hover_gates_role=rules.threshold_role;
        write_json(fullfile(folder,'protocol.json'),protocol);
        experiment=ca_prepare_experiment(c,ref.time_s);signature=allocation_comparison_hash({c,ref,experiment});
        save(fullfile(folder,sprintf('inputs_s%d.mat',seeds(si))),'c','model','ref','protocol','signature','-v7');
        for mi=1:numel(methods)
            index=(si-1)*numel(methods)+mi;seed=seeds(si);method=methods(mi);
            fprintf('FIG8_SEARCH %s %s seed%d %s 52s\n',stage,id,seed,method);
            try
                L=ca_simulate(model,c,ref,method,experiment);L.time_for_metrics=ref.time_s;
                assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'), ...
                    'ca:SearchTopicAudit','lite出现真值反馈topic。');
                assert(~any(L.table_extrapolated),'ca:AeroTableDomain','气动表越界。');L=rmfield(L,'topic_log');
                save(fullfile(folder,'logs',sprintf('%s_s%d.mat',method,seed)),'L','c','ref','model','protocol','signature','-v7');
                [part,state_part]=products(L,model,ref,protocol,seed,folder);S=[S;part];states=[states;state_part];
                geometry=table();
                if stage=="screen"||startsWith(method,"PCA")
                    geometry=ca_priority_polytope_audit(L,model,c,ref.time_s,protocol.evaluation_window_s);
                    writetable(geometry,fullfile(folder,sprintf('geometry_%s_s%d.csv',method,seed)));
                    if startsWith(method,"PCA")
                        q=ref.time_s>=6&ref.time_s<=50;normal=L.mode(q)==0;observed=L.lambda(q);
                        predicted=geometry.static_lambda_max;if method=="PCA_PREDICTIVE",predicted=geometry.dynamic_lambda_max;end
                        assert(all(isfinite(predicted(normal)))&&max(abs(observed(normal)-predicted(normal)))<1e-6, ...
                            'ca:SearchGeometry','PCA缩放与独立支撑面可达性核对不一致。');
                    end
                end
                task=part(part.window=="task",:);
                passed=task.attitude_peak_deg<=5&&task.saturation_percent<=10&&task.estimated_attitude_rmse_deg<=2&&task.aero_extrapolated_count==0;
                good_position=task.position_nrmse<=rules.position_nrmse_max;
                if protocol.yaw_fundamental_deg==0,good_yaw=task.yaw_rmse_deg<=rules.zero_yaw_rmse_max_deg;
                else,good_yaw=task.yaw_nrmse<=rules.nonzero_yaw_nrmse_max;end
                static_percent=NaN;dynamic_percent=NaN;
                if ~isempty(geometry),static_percent=100*mean(geometry.static_priority_certificate);dynamic_percent=100*mean(geometry.dynamic_priority_certificate);end
                quality=[quality;table(id,seed,method,passed,good_position,good_yaw,passed&&good_position&&good_yaw, ...
                    protocol.peak_horizontal_speed_m_s,protocol.peak_horizontal_acceleration_m_s2,protocol.peak_yaw_rate_deg_s, ...
                    task.position_rmse_m,task.position_nrmse,task.yaw_rmse_deg,task.yaw_nrmse,task.attitude_peak_deg, ...
                    task.saturation_percent,task.estimated_attitude_rmse_deg,static_percent,dynamic_percent, ...
                    task.lambda_scaled_percent,task.actuator_estimate_rmse_deg,task.prediction_rmse_deg, ...
                    'VariableNames',{'scenario_id','seed','method','legacy_hover_gates_passed','legacy_position_screen_passed','legacy_yaw_screen_passed','legacy_combined_screen_passed', ...
                    'reference_peak_speed_m_s','reference_peak_acceleration_m_s2','reference_peak_yaw_rate_deg_s', ...
                    'position_rmse_m','position_nrmse','yaw_rmse_deg','yaw_nrmse','attitude_peak_deg','saturation_percent','estimated_attitude_rmse_deg', ...
                    'frozen_static_priority_certificate_percent','frozen_dynamic_priority_certificate_percent','actual_lambda_scaled_percent', ...
                    'actuator_estimate_rmse_deg','pwm_prediction_rmse_deg'})];
                plan.status(index)="completed";
                provenance=[provenance;table(id,method,seed,signature,protocol.reference_hash,true,false,L.elapsed_s, ...
                    'VariableNames',{'scenario_id','method','seed','input_signature','reference_hash','truth_topics_absent','cache_loaded','simulation_elapsed_s'})];
                fprintf('FIG8_SEARCH_DONE %s seed%d %s peak=%.6g posNRMSE=%.6g yawNRMSE=%.6g legacy_screen_only=%d\n', ...
                    id,seed,method,task.attitude_peak_deg,task.position_nrmse,task.yaw_nrmse,passed&&good_position&&good_yaw);
                clear L geometry
            catch problem
                plan.status(index)="failed";plan.error_id(index)=string(problem.identifier);plan.error_message(index)=string(problem.message);
                plan.aero_extrapolated(index)=strcmp(problem.identifier,'ca:AeroTableDomain');
                write_json(fullfile(folder,'failures',sprintf('%04d.json',index)),struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
                fprintf('FIG8_SEARCH_FAILED %s seed%d %s %s: %s\n',id,seed,method,problem.identifier,problem.message);
            end
            writetable(plan,fullfile(folder,'status.csv'));writetable(S,fullfile(folder,'summary.csv'));writetable(states,fullfile(folder,'state_metrics.csv'));
            writetable(provenance,fullfile(folder,'provenance.csv'));writetable(quality,fullfile(out,'screen_quality.csv'));
        end
    end
    C=allocation_comparability(S,plan);writetable(C,fullfile(folder,'legacy_hover_comparability.csv'));
    write_json(fullfile(folder,'task_evaluation.json'),struct('evaluation_policy',rules.evaluation_policy, ...
        'completed',sum(plan.status=="completed"),'failed',sum(plan.status=="failed"),'not_run',sum(plan.status=="not_run"), ...
        'task_acceptance_criteria_validated',false,'legacy_hover_gates_define_task_qualification',false, ...
        'interpretation',"按指标描述结果；完成、模型域、跟踪品质、优先级激励分别评价，不生成动态rankable或自动排名"));
    all_summary=[all_summary;S];all_states=[all_states;states];all_status=[all_status;plan];
    writetable(all_status,fullfile(out,'status.csv'));writetable(all_summary,fullfile(out,'summary.csv'));
end
selection=struct('has_qualifying_candidate',false,'selected_scenario',"",'stage',stage,'all_candidates_retained',true, ...
    'selection_performed',false,'reason',"悬停门禁不用于动态轨迹筛选；没有验证过的动态任务验收依据，暂不自动选择");
if stage=="screen"
    write_json(fullfile(out,'selection.json'),selection);
end
study=struct('output_dir',out,'stage',stage,'summary',all_summary,'state_metrics',all_states,'status',all_status,'quality',quality,'selection',selection);
save(fullfile(out,'study.mat'),'study','-v7');
fprintf('FIG8_SEARCH_COMPLETE %s completed=%d/%d failed=%d selected=%s\n',stage,sum(all_status.status=="completed"),height(all_status),sum(all_status.status=="failed"),selection.selected_scenario);
end

function [S,states]=products(L,m,ref,protocol,seed,folder)
% 所有误差来自完整800Hz日志；几何速度仅评价，姿态和角速度取本次控制器实际指令。
target=[ref.position_ned_m,ref.velocity_ned_m_s,rad2deg(L.desired_euler_rad),rad2deg(L.omega_reference_rad_s)];
actual=[L.position_ned_m,L.velocity_ned_m_s,rad2deg(L.euler_rad),rad2deg(L.omega_rad_s)];
estimate=[L.estimated_position_ned_m,L.estimated_velocity_ned_m_s,rad2deg(L.measured_euler_rad),rad2deg(L.measured_omega_rad_s)];
errors=actual-target;errors(:,7:9)=rad2deg(atan2(sin(deg2rad(errors(:,7:9))),cos(deg2rad(errors(:,7:9)))));
assert(all(isfinite([actual,target,estimate]),'all'),'十二状态存在非有限数。');
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];
units=[repmat("m",1,3),repmat("m_s",1,3),repmat("deg",1,3),repmat("deg_s",1,3)];
bounds=[0,52;protocol.evaluation_window_s;protocol.cruise_window_s;0,6];windows=["whole","task","cruise","transient"];
S=table();states=table();
for wi=1:4
    mask=ref.time_s>=bounds(wi,1)&ref.time_s<=bounds(wi,2);
    row=estimator_feedback_metrics_row(L,m,protocol.case_id,"lite",seed,windows(wi),bounds(wi,:));
    row.scenario_id=protocol.scenario_id;row.attitude_peak_deg=max(rad2deg(L.rotation_error_rad(mask)));
    row.position_peak_m=max(vecnorm(errors(mask,1:3),2,2));row.velocity_rmse_m_s=sqrt(mean(sum(errors(mask,4:6).^2,2)));
    row.inner_rate_command_rmse_deg_s=sqrt(mean(sum(errors(mask,10:12).^2,2)));
    radius=sqrt(mean(sum(ref.position_ned_m(mask,1:2).^2,2)));row.position_nrmse=NaN;
    if radius>1e-12,row.position_nrmse=row.position_rmse_m/radius;end
    yaw_scale=sqrt(mean(rad2deg(ref.euler_rad(mask,3)).^2));row.yaw_nrmse=NaN;
    if yaw_scale>1e-12,row.yaw_nrmse=row.yaw_rmse_deg/yaw_scale;end
    row.aero_extrapolated_count=sum(L.table_extrapolated);row.load_fraction=0.6;row.smoke_test=false;
    row.actuator_estimate_rmse_deg=sqrt(mean(rad2deg(L.estimated_delta_rad(mask,:)-L.actual_delta_rad(mask,:)).^2,'all'));
    row.lambda_scaled_percent=NaN;row.lambda_min=NaN;
    if startsWith(string(L.name),"PCA")
        row.lambda_scaled_percent=100*mean(L.mode(mask)==0&isfinite(L.lambda(mask))&L.lambda(mask)<1-1e-6);
        v=L.lambda(mask);v=v(isfinite(v));if ~isempty(v),row.lambda_min=min(v);end
    end
    S=[S;row];
    for j=1:12
        e=errors(mask,j);states=[states;table(string(L.name),seed,windows(wi),names(j),units(j),sqrt(mean(e.^2)),mean(abs(e)),max(abs(e)),mean(e), ...
            'VariableNames',{'method','seed','window','state','unit','rmse','mae','peak_abs','bias'})];
    end
end
keep=1:8:numel(ref.time_s);track=array2table([ref.time_s(keep),target(keep,:),actual(keep,:),estimate(keep,:)], ...
    'VariableNames',cellstr(["time_s","target_"+names,"actual_"+names,"estimate_"+names]));
writetable(track,fullfile(folder,'tracks',sprintf('%s_s%d.csv',L.name,seed)));
end

function write_json(path,value)
% 在第一条仿真前冻结规则，之后逐条落盘保留失败与候选选择证据。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
