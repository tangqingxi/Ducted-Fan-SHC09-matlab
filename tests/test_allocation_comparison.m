function report = test_allocation_comparison()
% 两秒四十项及缓存、独立重复、故障继续与人工门禁夹具；不运行正式九十项。
root=ca_setup();test_allocation_comparability;assert(allocation_comparison_hash(uint8('abc'),true)=="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");tag=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
a=allocation_comparison_app('cases',["M0","M2b"],'seeds',[1,2],'smoke_test',true,'use_cached',false,'output_tag','test_'+tag+'_fresh');
assert(a.completed&&height(a.status)==40&&height(a.summary)==120&&height(a.effect_sizes)==204&&height(a.pareto)==540);
assert(all(a.comparability.comparability=="stress")&&~any(a.pareto.pareto_candidate)&&all(a.effect_sizes.distinguishable=="not_distinguishable"));
assert(all(a.provenance.topic_check(a.provenance.estimator_mode=="lite")=="verified_absent"));
assert(all(a.summary.window_start_s==0)&all(a.summary.window_end_s==2));
assert(all(ismember(["pooled_seed_std","method_range","range_over_seed_std","distinguishable","mean_DCA","std_DCA","n_DCA"],string(a.effect_sizes.Properties.VariableNames))));
b=allocation_comparison_app('cases',["M0","M2b"],'seeds',[1,2],'smoke_test',true,'reuse_from',a.output_dir,'use_cached',false,'output_tag','test_'+tag+'_reuse');
assert(b.completed&&all(b.provenance.loaded)&&isequaln(a.summary,b.summary)&&isequaln(a.pareto,b.pareto)&&isequaln(a.effect_sizes,b.effect_sizes));
% 每个种子内五方法的真实输入核对，不要求不同物理轨迹上的原始测量相同。
for id=["M0","M2b"],for mode=["ideal","lite"],for seed=[1,2]
 q=a.status.case_id==id & a.status.estimator_mode==mode & a.status.seed==seed;rows=a.status(q,:);
 assert(numel(unique(a.provenance.input_signature(q)))==1);
 first=load(fullfile(a.output_dir,'logs',rows.log_key(1)+'.mat'));
 for k=1:height(rows)
  other=load(fullfile(a.output_dir,'logs',rows.log_key(k)+'.mat'));
  assert(isequaln(first.c,other.c)&&isequaln(first.r,other.r));
  assert(isequal(first.L.gyro_noise_rad_s,other.L.gyro_noise_rad_s)&&isequal(first.L.disturbance_torque_nm,other.L.disturbance_torque_nm));
  assert(isequal(first.L.position_ned_m(1,:),other.L.position_ned_m(1,:))&&isequal(first.L.omega_rad_s(1,:),other.L.omega_rad_s(1,:)));
 end
end,end,end
q1=a.status.case_id=="M0" & a.status.estimator_mode=="lite" & a.status.method=="DA_NS" & a.status.seed==1;
q2=a.status.case_id=="M0" & a.status.estimator_mode=="lite" & a.status.method=="DA_NS" & a.status.seed==2;
seed1=load(fullfile(a.output_dir,'logs',a.status.log_key(q1)+'.mat'));seed2=load(fullfile(a.output_dir,'logs',a.status.log_key(q2)+'.mat'));
assert(~isequal(seed1.L.gyro_noise_rad_s,seed2.L.gyro_noise_rad_s),'不同种子没有改变实际注入噪声。');
independent=allocation_comparison_app('cases','M0','modes','lite','methods','DA_NS','seeds',2,'smoke_test',true,'use_cached',false,'output_tag','test_'+tag+'_independent');
q=a.status.case_id=="M0" & a.status.estimator_mode=="lite" & a.status.method=="DA_NS" & a.status.seed==2;
x=load(fullfile(a.output_dir,'logs',a.status.log_key(q)+'.mat'));y=load(fullfile(independent.output_dir,'logs',independent.status.log_key+'.mat'));
assert(isequaln(shc09_log_signature(x.L),shc09_log_signature(y.L)),'独立同种子数值日志不一致。');
xrows=a.summary(a.summary.case_id=="M0" & a.summary.estimator_mode=="lite" & a.summary.method=="DA_NS" & a.summary.seed==2,:);
assert(isequaln(removevars(xrows,'simulation_elapsed_s'),removevars(independent.summary,'simulation_elapsed_s')));
cached=allocation_comparison_app('cases','M0','modes','lite','methods','DA_NS','seeds',2,'smoke_test',true,'use_cached',true,'output_tag','test_'+tag+'_cache');
assert(cached.completed&&all(cached.provenance.loaded));
% 构造明确标识的人工统计夹具，不把烟雾数据当正式研究。
fixture=a;fixture.output_dir=fullfile(root,'results','allocation_synthetic_'+tag);mkdir(fixture.output_dir);
fixture.status.smoke_test(:)=false;fixture.status.duration_s(:)=20;fixture.summary.smoke_test(:)=false;
fixture.summary.saturation_percent(:)=10;fixture.summary.attitude_peak_deg(:)=5;fixture.summary.estimated_attitude_rmse_deg(:)=2;
fixture.summary.position_peak_m(:)=100;fixture.summary.aero_extrapolated_count(:)=0;
methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
for k=1:5
 q=fixture.summary.method==methods(k);fixture.summary.yaw_rmse_deg(q)=2*k+(2*fixture.summary.seed(q)-3);
end
fixture.summary.position_rmse_m(:)=1;fixture.summary.attitude_rmse_deg=2*fixture.summary.seed;
fixture.summary.moment_model_error_rms_nm(1)=NaN;
fixture.comparability=allocation_comparability(fixture.summary,fixture.status);assert(all(fixture.comparability.comparability=="rankable"),'固定门禁边界或额外位置阈值错误。');
fixture=allocation_comparison_products(fixture);F=fixture.effect_sizes;
q=F.metric=="yaw_rmse_deg";assert(all(abs(F.pooled_seed_std(q)-sqrt(2))<1e-12)&&all(F.method_range(q)==8)&&all(F.distinguishable(q)=="distinguishable"));
q=F.metric=="position_rmse_m";assert(all(isnan(F.range_over_seed_std(q)))&&all(F.zero_pooled_variance(q))&&all(F.distinguishable(q)=="not_distinguishable"));
q=F.metric=="attitude_rmse_deg";assert(all(F.range_over_seed_std(q)==0)&&all(F.distinguishable(q)=="not_distinguishable"));
assert(any(~F.complete_seed_coverage(F.metric=="moment_model_error_rms_nm")));
stress=fixture;stress.output_dir=fullfile(root,'results','allocation_synthetic_stress_'+tag);mkdir(stress.output_dir);
q=stress.summary.case_id=="M0" & stress.summary.estimator_mode=="lite" & stress.summary.window=="task";
stress.summary.saturation_percent(q)=10.0001;stress.comparability=allocation_comparability(stress.summary,stress.status);
assert(stress.comparability.comparability(stress.comparability.case_id=="M0" & stress.comparability.estimator_mode=="lite")=="stress");
stress=allocation_comparison_products(stress);q=stress.pareto.case_id=="M0" & stress.pareto.estimator_mode=="lite";
assert(~any(stress.pareto.pareto_candidate(q))&&all(stress.pareto.ranking_status(q)=="stress_not_ranking"));
% 损坏单个重放元数据，检验不静默兜底、后项继续以及可选快速停止。
fault=fullfile(root,'results','allocation_fault_fixture_'+tag);mkdir(fault);mkdir(fullfile(fault,'logs'));
q=a.status.case_id=="M0" & a.status.estimator_mode=="ideal" & a.status.seed==1 & a.status.method=="DA_NS";
key=a.status.log_key(q);saved=load(fullfile(a.output_dir,'logs',key+'.mat'));saved.c.gyro_noise_seed=saved.c.gyro_noise_seed+1;
save(fullfile(fault,'logs',key+'.mat'),'-struct','saved','-v7');
failed=allocation_comparison_app('cases','M0','modes','ideal','methods',["DA_NS","WLS"],'seeds',1,'smoke_test',true,'reuse_from',fault,'use_cached',false,'output_tag','test_'+tag+'_continue');
assert(isequal(failed.status.status,["failed";"completed"])&&height(failed.summary)==3&&isfile(fullfile(failed.output_dir,'failures','0001.json')));
assert(failed.comparability.comparability=="invalid");
stopped=allocation_comparison_app('cases','M0','modes','ideal','methods',["DA_NS","WLS"],'seeds',1,'smoke_test',true,'reuse_from',fault,'use_cached',false,'fail_fast',true,'output_tag','test_'+tag+'_stop');
assert(isequal(stopped.status.status,["failed";"not_run"])&&isempty(stopped.summary)&&~any(stopped.pareto.pareto_candidate));
assert(isequal(a.summary.Properties.VariableNames,stopped.summary.Properties.VariableNames),'全部失败时丢失输出列契约。');
domain=fixture.status;domain.aero_extrapolated(1)=true;domain.status(1)="failed";
invalid=allocation_comparability(fixture.summary,domain);assert(invalid.comparability(invalid.case_id=="M0" & invalid.estimator_mode=="ideal")=="invalid");
for file=["summary.csv","comparability.csv","effect_sizes.csv","pareto.csv","status.csv","provenance.csv","report.md","predefined_gates.json"]
 assert(isfile(fullfile(a.output_dir,file)));
end
report=struct('fresh_output',a.output_dir,'reused_output',b.output_dir,'independent_output',independent.output_dir,'completed',true,'gates_passed',true,'effects_passed',true,'stress_not_ranking',true,'failure_continue',true,'truth_topics_absent',true,'deterministic',true);disp(report);
end
