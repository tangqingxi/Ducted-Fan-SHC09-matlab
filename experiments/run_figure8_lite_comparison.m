function study = run_figure8_lite_comparison(varargin)
% 五方法共用八字参考和每个种子的随机输入；只新增实验和离线输出。
root=ca_setup();p=inputParser;
addParameter(p,'seeds',1:3);addParameter(p,'methods',["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"]);
addParameter(p,'output_tag',string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
parse(p,varargin{:});o=p.Results;seeds=reshape(o.seeds,1,[]);methods=reshape(string(o.methods),1,[]);
assert(~isempty(seeds)&&all(seeds>=1&seeds==fix(seeds)&seeds<2^32-80000)&&numel(unique(seeds))==numel(seeds));
assert(~isempty(methods)&&all(ismember(methods,["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"]))&&numel(unique(methods))==numel(methods));
assert(~isempty(regexp(char(o.output_tag),'^[A-Za-z0-9_-]+$','once')));
out=fullfile(root,'results','figure8_lite_M2b_'+string(o.output_tag));assert(~isfolder(out),'不覆盖既有八字结果目录。');
mkdir(out);mkdir(fullfile(out,'logs'));mkdir(fullfile(out,'tracks'));mkdir(fullfile(out,'failures'));
[base,model,~,~,old,cases]=ca_mismatch_protocol(20,0.6,"load_hold");
base.duration_s=52;base.estimator_mode="lite";base.save_results=false;base.save_figures=false;base.show_figures=false;
% 沿用既有六成偏航负载，延长保持到八字结束，卸载过渡仍为原来的半秒。
base.disturbance_stages_nm(end,1)=50;
item=cases(string({cases.id})=="M2b");base.vane_gain_scale=item.gains;
base.vane_deflection_map=string(item.mapping);base.vane_saturation_deg=item.saturation_deg;
base=ca_validate_config(base);assert(isequaln(ca_model(base),model),'私有失配不可进入名义分配模型。');
[ref,protocol]=ca_figure8_reference(base);protocol.external_yaw_nm=old.external_yaw_nm;
protocol.gains=item.gains;protocol.mapping=string(item.mapping);protocol.seed_list=seeds;protocol.methods=methods;
protocol.reference_hash=allocation_comparison_hash(ref);protocol.engine_fingerprint=allocation_comparison_engine(root);
protocol.study_source_hash=allocation_comparison_hash({fileread(mfilename('fullpath')+".m"),fileread(fullfile(root,'experiments','ca_figure8_reference.m'))});
protocol.head_commit=strtrim(string(evalc('system(''git rev-parse HEAD'');')));
protocol.primary_window="task [6,50]（含平滑起止），另报whole/cruise/transient，不替换旧协议";
protocol.seed_boxplot_unit="每种子一次完整运行的指标，不将时间采样当成独立试验";
protocol.gates=struct('attitude_peak_deg',5,'saturation_percent',10,'estimated_attitude_rmse_deg',2,'aero_extrapolated_count',0);
write_json(fullfile(out,'protocol.json'),protocol);
reference=array2table([ref.time_s,ref.position_ned_m,ref.velocity_ned_m_s,ref.acceleration_ned_m_s2], ...
    'VariableNames',{'time_s','x_m','y_m','z_m','vx_m_s','vy_m_s','vz_m_s','ax_m_s2','ay_m_s2','az_m_s2'});
writetable(reference,fullfile(out,'reference.csv'));
plan=table();
for seed=seeds,for method=methods
    plan=[plan;table("M2b",0.6,"lite",seed,method,false,"not_run","","",false, ...
        'VariableNames',{'case_id','load_fraction','estimator_mode','seed','method','smoke_test','status','error_id','error_message','aero_extrapolated'})];
end,end
S=table();states=table();provenance=table();writetable(plan,fullfile(out,'status.csv'));
for si=1:numel(seeds)
    c=base;
    for field=["gyro_noise_seed","attitude_noise_seed","disturbance_seed","lite_seed","navigation_seed"]
        c.(field)=c.(field)+seeds(si)-1;
    end
    c=ca_validate_config(c);experiment=ca_prepare_experiment(c,ref.time_s);
    signature=allocation_comparison_hash({c,ref,experiment});
    for mi=1:numel(methods)
        index=(si-1)*numel(methods)+mi;method=methods(mi);seed=seeds(si);
        fprintf('FIGURE8 %d/%d M2b lite seed%d %s 52s\n',index,height(plan),seed,method);
        try
            L=ca_simulate(model,c,ref,method,experiment);L.time_for_metrics=ref.time_s;
            assert(~isfield(L.topic_log,'plant_truth')&&~isfield(L.topic_log,'sensor_attitude')&&~isfield(L.topic_log,'sensor_local_position'), ...
                'ca:Figure8TopicAudit','lite日志出现真值反馈topic。');
            assert(~any(L.table_extrapolated),'ca:AeroTableDomain','八字轨迹气动越界。');
            L=rmfield(L,'topic_log');
            save(fullfile(out,'logs',sprintf('%s_s%d.mat',method,seed)),'L','c','ref','model','protocol','signature','-v7');
            target=[ref.position_ned_m,ref.velocity_ned_m_s,rad2deg(L.desired_euler_rad),rad2deg(L.omega_reference_rad_s)];
            actual=[L.position_ned_m,L.velocity_ned_m_s,rad2deg(L.euler_rad),rad2deg(L.omega_rad_s)];
            estimate=[L.estimated_position_ned_m,L.estimated_velocity_ned_m_s,rad2deg(L.measured_euler_rad),rad2deg(L.measured_omega_rad_s)];
            errors=actual-target;errors(:,7:9)=rad2deg(atan2(sin(deg2rad(errors(:,7:9))),cos(deg2rad(errors(:,7:9)))));
            assert(all(isfinite([target,actual,estimate]),'all'),'十二状态包含非有限数。');
            names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];
            units=[repmat("m",1,3),repmat("m_s",1,3),repmat("deg",1,3),repmat("deg_s",1,3)];
            bounds=[0,52;protocol.evaluation_window_s;protocol.cruise_window_s;0,6];windows=["whole","task","cruise","transient"];
            for wi=1:numel(windows)
                row=estimator_feedback_metrics_row(L,model,"M2b","lite",seed,windows(wi),bounds(wi,:));
                mask=ref.time_s>=bounds(wi,1)&ref.time_s<=bounds(wi,2);
                row.attitude_peak_deg=max(rad2deg(L.rotation_error_rad(mask)));
                row.position_peak_m=max(vecnorm(errors(mask,1:3),2,2));
                row.velocity_rmse_m_s=sqrt(mean(sum(errors(mask,4:6).^2,2)));
                row.inner_rate_command_rmse_deg_s=sqrt(mean(sum(errors(mask,10:12).^2,2)));
                row.aero_extrapolated_count=sum(L.table_extrapolated);row.load_fraction=0.6;row.smoke_test=false;
                S=[S;row];
                for j=1:12
                    e=errors(mask,j);states=[states;table(method,seed,windows(wi),names(j),units(j),sqrt(mean(e.^2)),mean(abs(e)),max(abs(e)),mean(e), ...
                        'VariableNames',{'method','seed','window','state','unit','rmse','mae','peak_abs','bias'})];
                end
            end
            % 可读跟踪表降采样到100Hz；全部800Hz原始值始终保留在MAT日志。
            keep=1:8:numel(ref.time_s);track=array2table([ref.time_s(keep),target(keep,:),actual(keep,:),estimate(keep,:)], ...
                'VariableNames',cellstr(["time_s","target_"+names,"actual_"+names,"estimate_"+names]));
            writetable(track,fullfile(out,'tracks',sprintf('%s_s%d.csv',method,seed)));
            provenance=[provenance;table(method,seed,signature,protocol.reference_hash,protocol.engine_fingerprint,true,false,L.elapsed_s, ...
                'VariableNames',{'method','seed','input_signature','reference_hash','engine_fingerprint','truth_topics_absent','cache_loaded','simulation_elapsed_s'})];
            plan.status(index)="completed";
            fprintf('FIGURE8_DONE %s seed%d elapsed=%.1fs\n',method,seed,L.elapsed_s);
            clear L track target actual estimate errors
        catch problem
            plan.status(index)="failed";plan.error_id(index)=string(problem.identifier);plan.error_message(index)=string(problem.message);
            plan.aero_extrapolated(index)=strcmp(problem.identifier,'ca:AeroTableDomain');
            write_json(fullfile(out,'failures',sprintf('%04d.json',index)),struct('identifier',problem.identifier,'message',problem.message,'stack',problem.stack));
            fprintf('FIGURE8_FAILED %s seed%d %s: %s\n',method,seed,problem.identifier,problem.message);
        end
        writetable(plan,fullfile(out,'status.csv'));writetable(S,fullfile(out,'summary.csv'));writetable(states,fullfile(out,'state_metrics.csv'));
        writetable(provenance,fullfile(out,'provenance.csv'));
    end
end
C=allocation_comparability(S,plan);writetable(C,fullfile(out,'comparability.csv'));
study=struct('output_dir',out,'protocol',protocol,'summary',S,'state_metrics',states,'status',plan,'comparability',C,'provenance',provenance);
save(fullfile(out,'study.mat'),'study','-v7');
fprintf('FIGURE8_COMPLETE %d/%d failed=%d output=%s\n',sum(plan.status=="completed"),height(plan),sum(plan.status=="failed"),out);
end

function write_json(path,value)
% 逐项落盘，保留协议和失败的原始证据。
fid=fopen(path,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
