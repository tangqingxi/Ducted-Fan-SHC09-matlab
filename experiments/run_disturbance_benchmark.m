function results = run_disturbance_benchmark(overrides)
% 借鉴UAV_Algorithm_Benchmark：场景、等级、重复、方法组织；保留本项目六舵面与PWM。
if nargin<1, overrides=struct(); end
folder=ca_setup();
cfg=ca_benchmark_config();
names=fieldnames(overrides);
for k=1:numel(names)
    assert(isfield(cfg,names{k}),'未知批量配置项：%s',names{k});
    cfg.(names{k})=overrides.(names{k});
end
cfg.scenarios=reshape(string(cfg.scenarios),1,[]);
cfg.methods=reshape(string(cfg.methods),1,[]);
assert(~isempty(cfg.scenarios) && all(ismember(cfg.scenarios,["hold","tracking"])) ...
    && numel(unique(cfg.scenarios))==numel(cfg.scenarios),'场景列表错误。');
assert(isscalar(cfg.num_repeats) && isfinite(cfg.num_repeats) && cfg.num_repeats>=1 ...
    && cfg.num_repeats==fix(cfg.num_repeats),'重复次数须为正整数。');
assert(isscalar(cfg.eval_start_s) && isfinite(cfg.eval_start_s) && cfg.eval_start_s>=0 ...
    && cfg.eval_start_s<min(cfg.duration_s,cfg.eval_end_s),'评价时间窗为空。');
assert(~isempty(cfg.levels),'扰动等级不能为空。');
level_names=string({cfg.levels.name});
assert(numel(unique(level_names))==numel(level_names),'扰动等级名称不能重复。');
for value=[cfg.scenarios,level_names,string(cfg.output_tag)]
    assert(~isempty(regexp(value,'^[A-Za-z0-9_-]+$','once')),'路径标签含非法字符。');
end
base=ca_config();
names=fieldnames(cfg.simulation_overrides);
for k=1:numel(names)
    assert(isfield(base,names{k}),'未知物理配置项：%s',names{k});
    base.(names{k})=cfg.simulation_overrides.(names{k});
end
base.duration_s=cfg.duration_s;
base.methods=cfg.methods;
base.disturbance_type="random";
base.disturbance_start_s=cfg.disturbance_start_s;
base.disturbance_end_s=cfg.disturbance_end_s;
base.random_moment_correlation_s=cfg.moment_correlation_s;
base.attitude_noise_std_deg=cfg.attitude_noise_std_deg;
base.save_figures=false;
base.save_results=false;
base=ca_validate_config(base);
out=fullfile(folder,'results','benchmark',cfg.output_tag);
assert(~isfolder(out),'批量结果目录已存在，请换output_tag以保留已有数据。');
% 先验证全部等级，避免启动一半才因配置错误停止。
for k=1:numel(cfg.levels)
    trial=base; trial.random_moment_rms_nm=cfg.levels(k).rms_nm;
    ca_validate_config(trial);
end
mkdir(out);
sources=dir(fullfile(folder,'**','*.m'));
sources=sources(~contains(string({sources.folder}),[filesep,'reference']));
implementation=cell(numel(sources),2);
for k=1:numel(sources)
    implementation{k,1}=fullfile(sources(k).folder,sources(k).name);
    implementation{k,2}=fileread(implementation{k,1});
end
environment=struct('matlab',version,'computer',computer,'created_at',char(datetime('now')));
reference=jsondecode(fileread(fullfile(folder,'docs','benchmark_reference.json')));
physical_reference=jsondecode(fileread(fullfile(folder,'docs','physical_reference.json')));
save(fullfile(out,'provenance.mat'),'implementation','environment','cfg','base','reference','physical_reference','-v7');
rows={};
row_names={'scenario','level','repeat','method','gyro_seed','attitude_seed','disturbance_seed', ...
    'status','error_id','error_message','rotation_rmse_deg','rotation_p95_deg','rotation_peak_deg', ...
    'rate_rmse_deg_s','command_step_rms_deg','solver_nonoptimal_count','mode1_count','mode2_count', ...
    'eval_start_s','eval_end_s','elapsed_s','realized_moment_rms_nm','aero_extrapolated_samples'};
total=numel(cfg.scenarios)*numel(cfg.levels)*cfg.num_repeats*numel(cfg.methods);
for scenario=cfg.scenarios
    for level=1:numel(cfg.levels)
        for repeat=1:cfg.num_repeats
            simcfg=base;
            simcfg.random_moment_rms_nm=cfg.levels(level).rms_nm;
            simcfg.gyro_noise_seed=ca_stable_seed(cfg.gyro_seed_base,scenario,cfg.levels(level).name,repeat);
            simcfg.attitude_noise_seed=ca_stable_seed(cfg.attitude_seed_base,scenario,cfg.levels(level).name,repeat);
            simcfg.disturbance_seed=ca_stable_seed(cfg.disturbance_seed_base,scenario,cfg.levels(level).name,repeat);
            if scenario=="hold"
                simcfg.roll_amplitude_deg=0; simcfg.pitch_amplitude_deg=0; simcfg.yaw_amplitude_deg=0;
            end
            simcfg=ca_validate_config(simcfg);
            model=ca_model(simcfg);
            ref=ca_reference(simcfg);
            experiment=ca_prepare_experiment(simcfg,ref.time_s);
            run_dir=fullfile(out,char(scenario),cfg.levels(level).name,sprintf('r%03d',repeat));
            mkdir(run_dir);
            save(fullfile(run_dir,'inputs.mat'),'simcfg','model','ref','experiment','-v7');
            first_log=[];
            for method=cfg.methods
                started=tic;
                status='completed'; error_id=''; message=''; log=[];
                numbers=NaN(1,8);
                realized=NaN; extrapolated=NaN;
                try
                    log=ca_simulate(model,simcfg,ref,method,experiment);
                    extrapolated=sum(log.table_extrapolated);
                    if ~isempty(first_log)
                        assert(isequal(log.gyro_noise_rad_s,first_log.gyro_noise_rad_s) ...
                            && isequal(log.attitude_noise_rad,first_log.attitude_noise_rad) ...
                            && isequal(log.disturbance_torque_nm,first_log.disturbance_torque_nm) ...
                            && isequal(log.pwm_update_time_s,first_log.pwm_update_time_s), ...
                            'ca:UnpairedInputs','同次试验的方法输入或PWM不一致。');
                    else
                        first_log=log;
                    end
                    selected=ref.time_s>=cfg.eval_start_s & ref.time_s<=cfg.eval_end_s;
                    errors=rad2deg(log.rotation_error_rad(selected));
                    assert(~isempty(errors) && all(isfinite(errors)),'误差序列为空或出现非有限值。');
                    sorted=sort(errors);
                    index=1+0.95*(numel(sorted)-1);
                    if isscalar(sorted), p95=sorted; else, p95=interp1((1:numel(sorted))',sorted,index); end
                    events=log.pwm_update_time_s>=cfg.eval_start_s & log.pwm_update_time_s<=cfg.eval_end_s;
                    steps=diff(rad2deg(log.pwm_command_rad(events,:)));
                    if isempty(steps), step_rms=NaN; else, step_rms=sqrt(mean(steps.^2,'all')); end
                    rates=rad2deg(log.rate_error_rad_s(selected,:));
                    numbers=[sqrt(mean(errors.^2)),p95,max(errors),sqrt(mean(sum(rates.^2,2))), ...
                        step_rms,sum(log.solver_exitflag(selected)<=0),sum(log.mode(selected)==1),sum(log.mode(selected)==2)];
                    realized=sqrt(mean(sum(log.disturbance_torque_nm(selected,:).^2,2)));
                catch exception
                    status='failed'; error_id=exception.identifier; message=exception.message;
                    % 同输入检查失败说明基准不公平，应立即停止，不能当作某个方法性能差。
                    if strcmp(error_id,'ca:UnpairedInputs'), rethrow(exception); end
                end
                elapsed=toc(started);
                record=struct('method',method,'status',status,'error_id',error_id,'error_message',message);
                if cfg.save_trial_logs || strcmp(status,'failed')
                    method_dir=fullfile(run_dir,char(method)); mkdir(method_dir);
                    save(fullfile(method_dir,'trial.mat'),'log','record','-v7');
                end
                rows(end+1,:)={char(scenario),cfg.levels(level).name,repeat,char(method), ...
                    simcfg.gyro_noise_seed,simcfg.attitude_noise_seed,simcfg.disturbance_seed, ...
                    status,error_id,message,numbers(1),numbers(2),numbers(3),numbers(4),numbers(5), ...
                    numbers(6),numbers(7),numbers(8),cfg.eval_start_s,min(cfg.eval_end_s,cfg.duration_s),elapsed,realized,extrapolated}; %#ok<AGROW>
                fprintf('[%d/%d] %s/%s/r%d/%s: %s, RMS=%g度。\n', ...
                    size(rows,1),total,scenario,cfg.levels(level).name,repeat,method,status,numbers(1));
            end
            results=cell2table(rows,'VariableNames',row_names);
            save(fullfile(out,'checkpoint.mat'),'results','cfg');
            writetable(results,fullfile(out,'trials.csv'),'Encoding','UTF-8');
        end
    end
end
results=cell2table(rows,'VariableNames',row_names);
results.Properties.UserData.output_dir=out;
save(fullfile(out,'benchmark.mat'),'results','cfg');
writetable(results,fullfile(out,'trials.csv'),'Encoding','UTF-8');
if cfg.make_plots, render_disturbance_benchmark(results,cfg,out,cfg.show_figures); end
end
