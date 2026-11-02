function checks=audit_hover_filter_tuning(folders,output)
% 离线重建滤波历史与傅里叶投影，逐条核对来源、输入与日志，不重飞。
root=ca_setup();addpath(fullfile(root,'research','ppid_pindi'));addpath(fullfile(root,'research','hover_distance'));
addpath(fullfile(root,'research','hover_distance_formal_20261102'));addpath(fullfile(root,'research','hover_distance_filter_20261102'));
assert(~isfolder(output));mkdir(output);mkdir(fullfile(output,'residual_tracks'));rows=table();maximum_trim=0;maximum_fourier=0;reproduction=table();
for folder=reshape(string(folders),1,[])
    sources=jsondecode(fileread(fullfile(folder,'sources.json')));assert(strcmp(jsonencode(sources),jsonencode(hft_sources(root))));
    status=readtable(fullfile(folder,'status.csv'),'TextType','string');S=readtable(fullfile(folder,'tuning.csv'),'TextType','string');
    for index=1:height(status)
        st=status(index,:);path=fullfile(folder,'logs',sprintf('H%02d_%02d_%s_s%d.mat',st.h1_hz,st.h2_hz,st.method,st.seed));
        if st.status~="completed",continue;end
        d=load(path);L=d.L;hd_check_log(L,d.ref,d.plan);
        old=load(fullfile(root,'results','hover_distance_formal_20261102_r1','inputs',sprintf('seed%d.mat',st.seed)));
        restore=d.plan;restore.controller.indi_output_filter_hz=8;restore.controller.indi_input_filter_hz=8;
        assert(isequaln(d.cfg,old.cfg)&&isequaln(d.model,old.model)&&isequaln(d.ref,old.ref)&&isequaln(restore,old.plan));
        experiment=ppid_noise(d.cfg,d.ref,d.plan);experiment.disturbance_series=d.cfg.disturbance_series;
        assert(isequaln(experiment,old.experiment));assert(allocation_comparison_hash({d.cfg,d.model,d.ref,experiment,d.plan})==string(d.signature));
        sc=shc09_module_params(d.cfg,'sensors');sc.sample_hz=400;sc.filter_h1_hz=st.h1_hz;sc.filter_h2_hz=st.h2_hz;
        sensor=ca_sensor_init(sc,d.model.trim_delta_rad);
        for sample=reshape(find(L.control_updated),1,[])
            [measurement,sensor]=ca_sensor_step(L.measured_omega(sample,:)',L.estimated_delta(sample,:)',zeros(3,1),sensor,sc);
            expected=d.model.acceleration_matrix*measurement.delta_feedback-measurement.alpha;
            maximum_trim=max(maximum_trim,max(abs(expected-L.v_h(sample,:)')));
        end
        assert(maximum_trim<1e-10);
        q=L.control_updated&L.time_s>=10&L.time_s<22;t=L.time_s(q);M=zeros(numel(t),3);
        % 直接按协议解析重建外扰，独立于日志使用的插值序列。
        z=min(1,max(0,(t-10)/.5));envelope=10*z.^3-15*z.^4+6*z.^5;
        M(:,1)=d.spec.roll_disturbance_amplitude_nm*envelope.*sin(2*pi*.5*(t-10));a=(d.model.inertia\M')';r=L.v_h(q,:)+a;
        X=[ones(numel(t),1),sin(2*pi*.5*t),cos(2*pi*.5*t)];fit=X\r;reference=X\a;
        ratio=hypot(fit(2,1),fit(3,1))/hypot(reference(2,1),reference(3,1));
        saved=S(S.h1_hz==st.h1_hz&S.h2_hz==st.h2_hz&S.method==st.method&S.seed==st.seed,:);
        difference=abs(ratio-saved.residual_roll_ratio);maximum_fourier=max(maximum_fourier,difference);assert(difference<1e-10);
        T=table(t,r(:,1),r(:,2),r(:,3),a(:,1),L.v_h(q,1), ...
            'VariableNames',{'time_s','residual_roll','residual_pitch','residual_yaw','disturbance_equivalent_roll','nu_h_roll'});
        writetable(T,fullfile(output,'residual_tracks',sprintf('H%02d_%02d_%s_s%d.csv',st.h1_hz,st.h2_hz,st.method,st.seed)));
        rows=[rows;table(st.h1_hz,st.h2_hz,st.method,st.seed,ratio,difference,string(d.signature), ...
            'VariableNames',{'h1_hz','h2_hz','method','seed','independent_roll_ratio','fourier_error','input_signature'})]; %#ok<AGROW>
        if st.h1_hz==8&&st.h2_hz==8
            nominal=load(fullfile(root,'results','hover_distance_formal_20261102_r1','logs',sprintf('%s_s%d.mat',st.method,st.seed)),'L');
            delta=max(abs([nominal.L.position-L.position,nominal.L.euler-L.euler,nominal.L.omega-L.omega,nominal.L.actual_delta-L.actual_delta]),[],'all');
            assert(delta<1e-10);reproduction=[reproduction;table(st.method,st.seed,delta,'VariableNames',{'method','seed','maximum_state_difference'})]; %#ok<AGROW>
        end
    end
end
writetable(rows,fullfile(output,'independent_checks.csv'));writetable(reproduction,fullfile(output,'nominal_8_8_regression.csv'));
checks=struct('logs_verified',height(rows),'maximum_trim_error',maximum_trim,'maximum_independent_fourier_error',maximum_fourier, ...
    'only_filter_fields_changed',true,'same_noise_and_reference',true,'flight_simulations_run',0);
fid=fopen(fullfile(output,'checks.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));fclose(fid);disp(checks);
end
