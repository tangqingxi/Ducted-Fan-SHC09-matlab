function gnss1000_run()
% 仅执行一次55秒闭环回归；其余检查只生成噪声或离线重算指标。
root=fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
cd(root);ca_setup();here=fileparts(mfilename('fullpath'));doc=fileparts(here);
out=fullfile(root,'results','gnss_1000s_regression_20261104_r1');
target=fullfile(out,'PCA_PREDICTIVE_s501.mat');assert(~isfile(target),'gnssv2:Exists','已有回归结果，不重复飞行。');
assert(isempty(getenv('ECL_HACC'))&&isempty(getenv('ECL_TIME_MODE')),'gnssv2:Environment','存在ECL参数环境覆盖。');
[cfg,model,ref,plan,spec]=shc09_gnss_config(501,"takeoff55");
[old_cfg,old_model,old_ref,old_plan]=hdtf_config(501);
assert(isequaln(cfg,old_cfg)&&isequaln(model,old_model)&&isequaln(ref,old_ref));
compare_plan=rmfield(plan,'gnss_model');compare_plan.sensors=old_plan.sensors;
assert(isequaln(compare_plan,old_plan));
assert(plan.sensors.gnss_correlation_s==1000&&old_plan.sensors.gnss_correlation_s==60);
% 新配置入口同样支持原F8几何；仅检查加载，不运行另一条闭环。
[~,~,~,f8_plan]=shc09_gnss_config(501,"f8");assert(f8_plan.sensors.gnss_correlation_s==1000);
experiment=ppid_noise(cfg,ref,plan);
addpath(fullfile(root,'docs/validation/shc09_b_frame_20261104/round6_gnss_bias_drift_20261104/scripts'));
[replica,comp]=round5_components(cfg,ref,plan);
assert(isequaln(experiment,replica),'gnssv2:Recurrence','原噪声实现与独立分量重构不一致。');
old=load(fullfile(root,'results/round7_changeB_20261104/G_s501.mat'),'experiment','comp');
assert(isequaln(comp.white_m,old.comp.white_m),'gnssv2:WhiteRng','白噪声随机序列发生变化。');
assert(isequaln(rmfield(experiment.navigation,'gnss_position_m'),rmfield(old.experiment.navigation,'gnss_position_m')), ...
    'gnssv2:OtherRng','其他传感器随机序列发生变化。');
dt=1/cfg.sample_hz;tau=plan.sensors.gnss_correlation_s;phi=exp(-dt/tau);
assert(abs(phi^(tau*cfg.sample_hz)-exp(-1))<1e-8);
assert(abs(phi^(cfg.sample_hz/cfg.gnss_hz)-exp(-1/(cfg.gnss_hz*tau)))<1e-12);
sigma_total=cfg.gnss_position_std_m(:);sigma_white=plan.sensors.gnss_white_axis_sigma_m(:);
sigma_slow=sqrt(sigma_total.^2-sigma_white.^2);sigma_drive=sigma_slow*sqrt(1-phi^2);
assert(max(abs(sigma_drive.^2/(1-phi^2)+sigma_white.^2-sigma_total.^2))<1e-12);
noise_checks=struct('tau_s',tau,'dt_s',dt,'phi_per_imu_sample',phi,'phi_per_gnss_update',phi^160, ...
    'sigma_total_m',sigma_total,'sigma_white_m',sigma_white,'sigma_slow_m',sigma_slow, ...
    'sigma_drive_m',sigma_drive,'original_generator_reconstructed_exactly',true,'white_rng_exact',true, ...
    'other_sensor_rng_exact',true,'physical_time_constant_checked',true,'variance_identity_checked',true);
write_json(fullfile(doc,'noise_checks.json'),noise_checks);
sources=ppid_source_manifest(root);
extra=["shc09_gnss_config.m","research/ppid_pindi/gnss_v2/protocol.json", ...
    "research/ppid_pindi/gnss_v2/ppid_gnss_v2_config.m",string(strrep(mfilename('fullpath'),[root,filesep],''))+".m"];
new_files=struct('path',{},'sha256',{});
for rel=extra
    fid=fopen(fullfile(root,rel),'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    new_files(end+1)=struct('path',rel,'sha256',allocation_comparison_hash(bytes,true)); %#ok<AGROW>
end
source_lock=struct('base_sources',sources,'new_files',new_files,'gnss_model',plan.gnss_model);
write_json(fullfile(doc,'source_lock.json'),source_lock);
stderr_before=string({dir(fullfile(root,'build/px4_ecl/*.stderr.txt')).name});
fprintf('GNSS1000_SINGLE_REGRESSION_START seed=501 duration=55 method=PCA_PREDICTIVE\n');
L=ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",experiment,plan);
% 先保存完整成功日志，再进行严格的离线评价；评价失败不重飞。
save(target,'L','cfg','model','ref','plan','spec','experiment','comp','source_lock','-v7');
fprintf('GNSS1000_SAVED %s\n',target);
stderr_after=string({dir(fullfile(root,'build/px4_ecl/*.stderr.txt')).name});
created=setdiff(stderr_after,stderr_before);assert(numel(created)==1);
copyfile(fullfile(root,'build/px4_ecl',created),fullfile(out,'ecl_bridge_stderr.txt'));
assert(isequaln(ppid_source_manifest(root),sources),'gnssv2:SourcesChanged','原有数值源码在运行期间发生变化。');
[metrics,checks]=hdtf_metrics(L,cfg,model,ref,plan,501);
save(fullfile(out,'metrics.mat'),'metrics','checks','-v7');
writetable(struct2table(metrics,'AsArray',true),fullfile(doc,'original_scene_metrics.csv'));
write_json(fullfile(doc,'original_scene_checks.json'),checks);
fprintf('GNSS1000_REGRESSION_DONE precheck=%d data_valid=%d true_recovery_not_reached=%d\n', ...
    metrics.precheck_passed,metrics.data_valid,metrics.true_recovery_not_reached);
end

function write_json(path,value)
% 新派生文件仅写入本轮独立目录，不触碰任何旧锁或旧指标。
fid=fopen(path,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
