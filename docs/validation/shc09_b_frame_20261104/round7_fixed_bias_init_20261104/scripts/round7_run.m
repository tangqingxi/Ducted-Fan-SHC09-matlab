function round7_run()
% 本轮仅新增三条G组闭环；静置初始化重放不调用对象积分。
base=fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
cd(base);ca_setup();here=fileparts(mfilename('fullpath'));addpath(here);
addpath(fullfile(base,'docs/validation/shc09_b_frame_20261104/round6_gnss_bias_drift_20261104/scripts'));
for rel=["research/ppid_pindi","research/hover_distance","research/hover_distance_takeoff_20261103","research/hover_distance_takeoff_formal_20261103"]
    addpath(fullfile(base,rel));
end
out=fullfile(base,'results/round7_changeB_20261104');assert(isfolder(out));
for seed=[501 502 503]
    D=load(fullfile(base,'results/round6_changeB_20261104',sprintf('F_s%d.mat',seed)));
    [cfg,model,ref55,plan,spec]=hdtf_config(seed);
    assert(isequaln(cfg,D.cfg)&&isequaln(model,D.model)&&isequaln(plan,D.plan),'原始配置不一致');
    [original,comp]=round5_components(cfg,ref55,plan);check=ppid_noise(cfg,ref55,plan);
    assert(isequaln(original,check),'噪声重构与正式生成器不一致');
    assert(isequaln(comp,D.comp),'历史分量与重构分量不一致');
    slow0=comp.slow_m(comp.warmup_samples+1,:);assert(isequal(slow0,D.slow0));
    experiment=original;experiment.navigation.gnss_position_m=comp.white_m+slow0;
    without=@(x)rmfield(x,'gnss_position_m');
    assert(isequaln(without(experiment.navigation),without(original.navigation)),'其他噪声发生变化');
    assert(isequal(experiment.navigation.gnss_position_m-comp.white_m,repmat(slow0,size(comp.white_m,1),1))|| ...
        max(abs(experiment.navigation.gnss_position_m-comp.white_m-slow0),[],'all')<1e-15);
    ref=D.ref;cond="G";target=fullfile(out,sprintf('G_s%d.mat',seed));
    if ~isfile(target)
        fprintf('ROUND7_NEW_CLOSED_LOOP seed=%d cond=G samples=%d\n',seed,numel(ref.time_s));
        L=ppid_simulate(cfg,model,ref,"PCA_PREDICTIVE",experiment,plan);
        assert(numel(L.time_s)==9600&&all(isfinite(L.position),'all')&&~any(L.aero_outside));
        save(target,'L','ref','cfg','model','plan','spec','comp','cond','seed','slow0','experiment','-v7');
        fprintf('ROUND7_SAVED %s\n',target);
    else
        S=load(target,'experiment');assert(isequaln(S.experiment,experiment),'已有G组输入不一致');
        fprintf('ROUND7_REUSE_SAVED_G seed=%d\n',seed);
    end
    for cond=["A","F","B","G"]
        noise=original.navigation;
        if cond=="F"
            noise.gnss_position_m(comp.warmup_samples+1:end,:)=comp.white_m(comp.warmup_samples+1:end,:)+slow0;
        elseif cond=="G"
            noise.gnss_position_m=comp.white_m+slow0;
        elseif cond=="B"
            noise.gnss_position_m=comp.white_m;
        end
        assert(isequaln(without(noise),without(original.navigation)));
        target=fullfile(out,sprintf('init_%s_s%d.mat',cond,seed));
        if ~isfile(target)
            [nav,~,~,I]=round7_init(cfg,model,plan,noise);
            nav.bridge.close();
            if cond=="B",src=fullfile(base,'results/round5_changeB_20261104',sprintf('B_s%d.mat',seed));
            elseif cond=="G",src=fullfile(out,sprintf('G_s%d.mat',seed));
            else,src=fullfile(base,'results/round6_changeB_20261104',sprintf('%s_s%d.mat',cond,seed));end
            S=load(src,'L','ref');origin=I.raw(end,:)-S.ref.position_ned_m(1,:);
            assert(max(abs(origin-S.L.navigation_origin_offset'))<1e-12,'静置重放未复现原始坐标绑定');
            save(target,'I','cfg','comp','cond','seed','slow0','origin','-v7');
            fprintf('ROUND7_STATIC_REPLAY seed=%d cond=%s origin_max_error=%.3g\n',seed,cond,max(abs(origin-S.L.navigation_origin_offset')));
        end
    end
end
fprintf('ROUND7_ALL_RUNS_DONE\n');
end
