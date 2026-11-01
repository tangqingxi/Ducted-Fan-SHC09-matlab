function study=run_f8_comparison(stage,varargin)
% 正式F8按冻结协议运行两个场景的五方法三种子；烟雾使用独立开发种子且不冒充正式结果。
if nargin<1,stage="formal";end
root=ca_setup();stage=string(stage);assert(ismember(stage,["formal","smoke"]));p=inputParser;
addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));parse(p,varargin{:});
tag=string(p.Results.output_tag);assert(~isempty(regexp(char(tag),'^[A-Za-z0-9_-]+$','once')));
out=fullfile(root,'results','f8_v1_'+stage+'_'+tag);assert(~isfolder(out),'不覆盖既有F8结果。');mkdir(out);
frozen_path=fullfile(root,'configs','f8_protocol_v1.json');frozen_text=fileread(frozen_path);frozen=ca_f8_protocol();
copyfile(frozen_path,fullfile(out,'frozen_protocol.json'));engine=allocation_comparison_engine(root);
ids=string({frozen.scenarios.id});seeds=frozen.seeds(:)';methods=string(frozen.methods(:)');
if stage=="smoke",ids="F8-R";seeds=9001;methods="WLS";end
all_status=table();all_summary=table();
for id=ids
    folder=fullfile(out,id);mkdir(folder);mkdir(fullfile(folder,'logs'));mkdir(fullfile(folder,'tracks'));mkdir(fullfile(folder,'failures'));
    status=table();summary=table();states=table();provenance=table();
    for seed=seeds,for method=methods
        status=[status;table(id,method,seed,"not_run","","",'VariableNames',{'scenario_id','method','seed','status','error_id','error_message'})];
    end,end
    for seed=seeds
        build_seed=seed;if stage=="smoke",build_seed=frozen.seeds(1);end
        [c,m,ref,protocol]=ca_f8_protocol(id,build_seed);protocol.smoke_test=stage=="smoke";
        if stage=="smoke"
            for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"]
                c.(field)=c.(field)+seed-build_seed;
            end
            protocol.seed=seed;c.duration_s=8;count=round(c.duration_s*c.sample_hz)+1;original_count=numel(ref.time_s);
            for name=string(fieldnames(ref))'
                value=ref.(name);
                if isnumeric(value)&&size(value,1)==original_count,ref.(name)=value(1:count,:);
                elseif isnumeric(value)&&ndims(value)==3&&size(value,3)==original_count,ref.(name)=value(:,:,1:count);end
            end
            protocol.effective_smoke_duration_s=c.duration_s;
        end
        assert(isequal(fileread(frozen_path),frozen_text)&&engine==allocation_comparison_engine(root),'F8协议或引擎在运行中变化。');
        experiment=ca_prepare_experiment(c,ref.time_s);signature=allocation_comparison_hash({c,ref,experiment});
        write_json(fullfile(folder,'protocol.json'),protocol);
        for method=methods
            index=find(status.seed==seed&status.method==method);fprintf('F8_RUN %s %s seed%d %s %.1fs\n',stage,id,seed,method,c.duration_s);
            try
                L=ca_simulate(m,c,ref,method,experiment);L.time_for_metrics=ref.time_s;
                assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'), ...
                    'ca:F8TruthAudit','F8 lite出现真值反馈topic。');
                L=rmfield(L,'topic_log');save(fullfile(folder,'logs',sprintf('%s_s%d.mat',method,seed)),'L','c','m','ref','protocol','signature','-v7');
                [metrics,checks]=f8_evaluate_run(L,c,m,ref,protocol);
                metrics.command_step_rms_deg=sqrt(mean(diff(rad2deg(L.pwm_command_rad)).^2,'all'));
                metrics.actuator_estimate_rmse_deg=sqrt(mean(rad2deg(L.actual_delta_rad-L.estimated_delta_rad).^2,'all'));
                metrics.pwm_prediction_rmse_deg=sqrt(mean(rad2deg(L.pwm_end_prediction_error_rad(L.pwm_prediction_checked,:)).^2,'all','omitnan'));
                checks.priority_geometry_audited=false;checks.priority_geometry_total_scaled_s=NaN;checks.priority_geometry_longest_scaled_s=NaN;
                if startsWith(method,"PCA")
                    geometry=ca_priority_polytope_audit(L,m,c,ref.time_s,frozen.motion_window_s');
                    writetable(geometry,fullfile(folder,sprintf('priority_geometry_%s_s%d.csv',method,seed)));
                    certificate=geometry.static_priority_certificate;predicted=geometry.static_lambda_max;
                    if method=="PCA_PREDICTIVE",certificate=geometry.dynamic_priority_certificate;predicted=geometry.dynamic_lambda_max;end
                    q=ref.time_s>=frozen.motion_window_s(1)&ref.time_s<=frozen.motion_window_s(2);normal=L.mode(q)==0;observed=L.lambda(q);
                    assert(all(isfinite(predicted(normal)))&&max(abs(predicted(normal)-observed(normal)))<1e-6, ...
                        'ca:F8GeometryAudit','独立名义集合与原PCA缩放不一致。');
                    active=certificate&normal&isfinite(observed)&observed<1-frozen.priority_evidence.lambda_tolerance;
                    edges=diff([false;active(:);false]);lengths=find(edges==-1)-find(edges==1);
                    checks.priority_geometry_audited=true;checks.priority_geometry_total_scaled_s=sum(active)/c.sample_hz;
                    checks.priority_geometry_longest_scaled_s=max([0;lengths])/c.sample_hz;
                end
                summary=[summary;[struct2table(metrics,'AsArray',true),struct2table(checks,'AsArray',true)]];
                states=[states;write_tracking(L,ref,protocol,folder)];status.status(index)="completed";
                provenance=[provenance;table(id,method,seed,signature,protocol.frozen_protocol_hash,engine,true,protocol.smoke_test, ...
                    'VariableNames',{'scenario_id','method','seed','input_signature','frozen_protocol_hash','engine_fingerprint','truth_topics_absent','smoke_test'})];
                fprintf('F8_DONE %s seed%d %s horizontalRMS=%.6g yawRMS=%.6g task=%d formal=%d\n', ...
                    id,seed,method,metrics.horizontal_position_rmse_m,metrics.yaw_rmse_deg,checks.run_task_passed,stage=="formal");
                clear L geometry
            catch problem
                status.status(index)="failed";status.error_id(index)=string(problem.identifier);status.error_message(index)=string(problem.message);
                write_json(fullfile(folder,'failures',sprintf('%s_s%d.json',method,seed)), ...
                    struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
                fprintf('F8_FAILED %s seed%d %s %s: %s\n',id,seed,method,problem.identifier,problem.message);
            end
            writetable(status,fullfile(folder,'status.csv'));writetable(summary,fullfile(folder,'task_metrics.csv'));
            writetable(states,fullfile(folder,'state_metrics.csv'));writetable(provenance,fullfile(folder,'provenance.csv'));
            assert(isequal(fileread(frozen_path),frozen_text)&&engine==allocation_comparison_engine(root),'F8协议或引擎在运行中变化。');
        end
    end
    complete=stage=="formal"&&height(status)==15&&all(status.status=="completed")&&height(summary)==15;
    all_task=false;priority_claim=false;
    if complete
        all_task=all(summary.run_task_passed);
        for method=["PCA_STATIC","PCA_PREDICTIVE"]
            rows=summary(summary.method==method,:);
            good=rows.priority_geometry_audited ...
                &rows.priority_geometry_total_scaled_s>=frozen.priority_evidence.minimum_total_scaled_duration_s ...
                &rows.priority_geometry_longest_scaled_s>=frozen.priority_evidence.minimum_longest_scaled_episode_s;
            priority_claim=priority_claim||sum(good)>=frozen.priority_evidence.minimum_seeds_with_excitation;
        end
    end
    write_json(fullfile(folder,'task_evaluation.json'),struct('protocol_id',frozen.protocol_id,'stage',stage, ...
        'formal_completed',double(stage=="formal")*sum(status.status=="completed"),'failed',sum(status.status=="failed"), ...
        'all_five_methods_three_seeds_completed',complete,'all_five_methods_meet_task_requirements',all_task, ...
        'priority_excitation_and_nominal_geometry_requirements_met',priority_claim, ...
        'priority_effect_or_method_superiority_proven',false,'uses_hover_comparability_gates',false));
    all_status=[all_status;status];all_summary=[all_summary;summary];
    writetable(all_status,fullfile(out,'status.csv'));writetable(all_summary,fullfile(out,'task_metrics.csv'));
end
study=struct('output_dir',out,'stage',stage,'status',all_status,'summary',all_summary,'engine_fingerprint',engine, ...
    'frozen_protocol_hash',allocation_comparison_hash(frozen_text));save(fullfile(out,'study.mat'),'study','-v7');
fprintf('F8_COMPLETE %s completed=%d/%d failed=%d\n',stage,sum(all_status.status=="completed"),height(all_status),sum(all_status.status=="failed"));
end

function states=write_tracking(L,ref,protocol,folder)
% 共同几何参考与各次反馈指令分开保存；十二状态箱线图不混用方法自己的目标。
target=[ref.position_ned_m,ref.velocity_ned_m_s,rad2deg(ref.euler_rad),rad2deg(ref.omega_body_rad_s)];
actual=[L.position_ned_m,L.velocity_ned_m_s,rad2deg(L.euler_rad),rad2deg(L.omega_rad_s)];
estimate=[L.estimated_position_ned_m,L.estimated_velocity_ned_m_s,rad2deg(L.measured_euler_rad),rad2deg(L.measured_omega_rad_s)];
error=actual-target;error(:,7:9)=rad2deg(atan2(sin(deg2rad(error(:,7:9))),cos(deg2rad(error(:,7:9)))));
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];states=table();
bounds=[0,ref.time_s(end);protocol.motion_window_s';protocol.cruise_window_s';0,6];windows=["whole","task","cruise","initial_hover"];
for wi=1:4
    q=ref.time_s>=bounds(wi,1)&ref.time_s<=bounds(wi,2);if ~any(q),continue;end
    for k=1:12
        e=error(q,k);states=[states;table(string(L.name),protocol.seed,windows(wi),names(k),sqrt(mean(e.^2)),max(abs(e)), ...
            'VariableNames',{'method','seed','window','state','rmse','peak_abs'})];
    end
end
keep=1:8:numel(ref.time_s);T=array2table([ref.time_s(keep),target(keep,:),actual(keep,:),estimate(keep,:)], ...
    'VariableNames',cellstr(["time_s","target_"+names,"actual_"+names,"estimate_"+names]));
T.command_roll_deg=rad2deg(L.desired_euler_rad(keep,1));T.command_pitch_deg=rad2deg(L.desired_euler_rad(keep,2));
T.command_yaw_deg=rad2deg(L.desired_euler_rad(keep,3));
for k=1:3,T.("command_rate"+string(k)+"_deg_s")=rad2deg(L.omega_reference_rad_s(keep,k));end
writetable(T,fullfile(folder,'tracks',sprintf('%s_s%d.csv',L.name,protocol.seed)));
end

function write_json(path,value)
% 结果与冻结协议分开落盘，不覆盖原协议或既有实验目录。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
