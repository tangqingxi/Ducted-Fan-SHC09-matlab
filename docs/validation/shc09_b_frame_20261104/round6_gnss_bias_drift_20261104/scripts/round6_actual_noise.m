base='E:\Ducted-Fan-SHC09-matlab'; cd(base); addpath(fullfile(base,'results'));
r5=fullfile(base,'results','round5_changeB_20261104'); r6=fullfile(base,'results','round6_changeB_20261104');
rows={};
for seed=[501 502 503]
 for cond=["A","B","C","F"]
  if cond=="A"||cond=="F", d=load(fullfile(r6,sprintf('%s_s%d.mat',cond,seed)),'L','comp','slow0');
  else, d=load(fullfile(r5,sprintf('%s_s%d.mat',cond,seed)),'L','comp'); end
  L=d.L; comp=d.comp; warm=comp.warmup_samples; idx=find(L.gnss_fresh); ci=warm+idx;
  slowCfg=comp.slow_m(ci,1:2); whiteCfg=comp.white_m(ci,1:2);
  if cond=="A", slowAct=slowCfg;
  elseif cond=="F", slowAct=repmat(d.slow0(1:2),numel(idx),1);
  else, slowAct=zeros(numel(idx),2); end
  if cond=="C", whiteAct=zeros(numel(idx),2); else, whiteAct=whiteCfg; end
  gnssErr=L.gnss_position(idx,1:2)-L.position(idx,1:2);
  for j=1:numel(idx)
   rows{end+1}=table(seed,cond,L.time_s(idx(j)),idx(j),slowCfg(j,1),slowCfg(j,2),whiteCfg(j,1),whiteCfg(j,2), ...
    slowAct(j,1),slowAct(j,2),whiteAct(j,1),whiteAct(j,2),slowAct(j,1)+whiteAct(j,1),slowAct(j,2)+whiteAct(j,2), ...
    gnssErr(j,1),gnssErr(j,2), ...
    'VariableNames',{'seed','condition','time_s','mission_index','slow_cfg_n','slow_cfg_e','white_cfg_n','white_cfg_e', ...
    'slow_actual_n','slow_actual_e','white_actual_n','white_actual_e','total_actual_n','total_actual_e','gnss_err_n','gnss_err_e'});
  end
 end
end
T=vertcat(rows{:}); writetable(T,fullfile(r6,'round6_noise_components_actual.csv'));
for cond=["A","B","C","F"]
 for seed=[501 502 503]
  q=T.seed==seed&T.condition==cond; e=[T.gnss_err_n(q),T.gnss_err_e(q)];
  fprintf('%s s%d n=%d mean_vec=(%.3f,%.3f) mean_norm=%.3f rmse=%.3f std=(%.3f,%.3f)\n',cond,seed,sum(q),mean(e(:,1)),mean(e(:,2)),mean(vecnorm(e,2,2)),sqrt(mean(sum(e.^2,2))),std(e(:,1)),std(e(:,2)));
 end
end
