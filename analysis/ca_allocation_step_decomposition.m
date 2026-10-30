function table_out = ca_allocation_step_decomposition(results,window)
% 将PWM命令变化分成影响虚拟控制的行空间分量和不改变其名义值的零空间分量。
P=pinv(results.model.acceleration_matrix)*results.model.acceleration_matrix;
labels=string({results.variants.label}); rows={};
for label=labels
    if ~isfield(results.logs,label), continue; end
    log=results.logs.(label);
    selected=log.pwm_update_time_s>=window(1) & log.pwm_update_time_s<window(2);
    changes=diff(rad2deg(log.pwm_command_rad(selected,:)));
    affecting=changes*P'; redundant=changes-affecting;
    total=mean(changes.^2,'all'); first=mean(affecting.^2,'all'); second=mean(redundant.^2,'all');
    assert(abs(total-first-second)<1e-9*max(1,total),'行空间与零空间变化不满足能量分解。');
    ratio=NaN; if total>0, ratio=100*second/total; end
    rows(end+1,:)={char(results.scenario),char(label),sqrt(total),sqrt(first),sqrt(second),ratio}; %#ok<AGROW>
end
table_out=cell2table(rows,'VariableNames',{'scenario','variant','step_rms_deg','rowspace_step_rms_deg', ...
    'nullspace_step_rms_deg','nullspace_step_energy_percent'});
end
