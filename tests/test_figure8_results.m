function report = test_figure8_results(output_dir)
% 从十五条完整MAT日志独立重算十二状态指标和跟踪表，防止绘图使用错目标或错种子。
ca_setup();S=readtable(fullfile(output_dir,'summary.csv'),'TextType','string');
M=readtable(fullfile(output_dir,'state_metrics.csv'),'TextType','string');
P=readtable(fullfile(output_dir,'status.csv'),'TextType','string');
V=readtable(fullfile(output_dir,'provenance.csv'),'TextType','string');
protocol=jsondecode(fileread(fullfile(output_dir,'protocol.json')));
assert(height(P)==15&&all(P.status=="completed")&&height(S)==60&&height(M)==720);
assert(all(V.truth_topics_absent)&&~any(V.cache_loaded));
assert(strcmp(protocol.engine_fingerprint,allocation_comparison_engine(ca_setup())),'旧数值引擎发生变化。');
methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
names=["x","y","z","vx","vy","vz","roll","pitch","yaw","p","q","r"];
maximum_error=0;peaks=table();
for seed=1:3
    fingerprint="";reference_hash="";
    for method=methods
        d=load(fullfile(output_dir,'logs',sprintf('%s_s%d.mat',method,seed)));
        assert(string(d.L.name)==method&&string(d.c.estimator_mode)=="lite");
        assert(isequal(d.c.vane_gain_scale,[1.2;1;0.8;1;1.2;1])&&string(d.c.vane_deflection_map)=="linear");
        assert(d.model.command_limit_deg==40&&~any(d.L.table_extrapolated));
        assert(all(abs(d.L.command_rad)<=deg2rad(40)+1e-10,'all'));
        if strlength(fingerprint)==0,fingerprint=d.signature;reference_hash=allocation_comparison_hash(d.ref);end
        assert(string(d.signature)==fingerprint&&allocation_comparison_hash(d.ref)==reference_hash,'五方法的参考或公共随机输入不一致。');
        assert(reference_hash==string(protocol.reference_hash),'不同种子不得改变八字参考。');
        expected=[d.ref.position_ned_m,d.ref.velocity_ned_m_s,rad2deg(d.L.desired_euler_rad),rad2deg(d.L.omega_reference_rad_s)];
        truth=[d.L.position_ned_m,d.L.velocity_ned_m_s,rad2deg(d.L.euler_rad),rad2deg(d.L.omega_rad_s)];
        errors=truth-expected;errors(:,7:9)=rad2deg(atan2(sin(deg2rad(errors(:,7:9))),cos(deg2rad(errors(:,7:9)))));
        T=readtable(fullfile(output_dir,'tracks',sprintf('%s_s%d.csv',method,seed)));
        keep=1:8:numel(d.ref.time_s);assert(max(abs(T.time_s-d.ref.time_s(keep)))<1e-12);
        for j=1:12
            a=T.("target_"+names(j))-expected(keep,j);b=T.("actual_"+names(j))-truth(keep,j);
            assert(max(abs([a;b]))<1e-11,'跟踪表目标或真实状态与完整MAT不一致。');
        end
        bounds=[0,52;6,50;10,46;0,6];windows=["whole","task","cruise","transient"];
        for wi=1:4
            mask=d.ref.time_s>=bounds(wi,1)&d.ref.time_s<=bounds(wi,2);
            indices=find(mask);[peak,local_index]=max(rad2deg(d.L.rotation_error_rad(mask)));i=indices(local_index);
            peaks=[peaks;table(method,seed,windows(wi),d.ref.time_s(i),peak,rad2deg(d.L.estimated_attitude_error_rad(i)), ...
                norm(d.L.position_ned_m(i,:)-d.ref.position_ned_m(i,:)),max(abs(rad2deg(d.L.command_rad(i,:)))), ...
                max(abs(rad2deg(d.L.actual_delta_rad(i,:)))), ...
                'VariableNames',{'method','seed','window','peak_time_s','attitude_peak_deg','estimate_error_at_peak_deg', ...
                'position_error_at_peak_m','command_max_at_peak_deg','actual_delta_max_at_peak_deg'})];
            for j=1:12
                row=M(M.method==method&M.seed==seed&M.window==windows(wi)&M.state==names(j),:);
                assert(height(row)==1);actual=sqrt(mean(errors(mask,j).^2));
                difference=abs(actual-row.rmse);maximum_error=max(maximum_error,difference);
                assert(difference<1e-11,'十二状态RMSE未与完整MAT重算一致。');
            end
            row=S(S.method==method&S.seed==seed&S.window==windows(wi),:);assert(height(row)==1);
            assert(abs(peak-row.attitude_peak_deg)<1e-11,'姿态峰值未与完整MAT重算一致。');
            estimate_rms=sqrt(mean(rad2deg(d.L.estimated_attitude_error_rad(mask)).^2));
            assert(abs(estimate_rms-row.estimated_attitude_rmse_deg)<1e-11);
            events=d.L.pwm_update_time_s>=bounds(wi,1)&d.L.pwm_update_time_s<=bounds(wi,2);
            saturation=100*mean(any(abs(rad2deg(d.L.pwm_command_rad(events,:)))>=40-1e-5,2));
            assert(abs(saturation-row.saturation_percent)<1e-11,'饱和率必须按40度限幅重算。');
            position=sqrt(mean(sum(errors(mask,1:3).^2,2)));
            assert(abs(position-row.position_rmse_m)<1e-11);
            rate=sqrt(mean(sum(errors(mask,10:12).^2,2)));
            assert(abs(rate-row.inner_rate_command_rmse_deg_s)<1e-11);
        end
    end
end
C=allocation_comparability(S,P);saved=readtable(fullfile(output_dir,'comparability.csv'),'TextType','string');
assert(isequal(string(C.comparability),string(saved.comparability)));
writetable(peaks,fullfile(output_dir,'peak_diagnostics.csv'));
report=struct('logs_verified',15,'state_metric_rows_verified',height(M),'common_inputs_per_seed',true, ...
    'limit_deg',40,'truth_topic_audit_recorded',true,'maximum_csv_roundtrip_error',maximum_error,'engine_unchanged',true);
fid=fopen(fullfile(output_dir,'independent_checks.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));
fprintf('FIGURE8_INDEPENDENT_PASS 15 logs, 720 state metrics; maximum CSV error %.3g\n',maximum_error);
end
