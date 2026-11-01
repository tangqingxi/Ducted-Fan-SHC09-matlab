function report=audit_f8_thrust_envelope(output_dir)
% 静止轴向上界与原气动模型冻结力扫描分开；单点遥控杆量不拟合整条推力曲线。
root=ca_setup();if nargin<1,output_dir=fullfile(root,'results','f8_protocol_preflight_20261101');end
assert(~isfolder(output_dir),'不覆盖既有推力审计。');mkdir(output_dir);
[c,m,~,p]=ca_f8_protocol('F8-R',101);a=m.parameters;weight=m.mass_kg*a.g;maximum=a.Duct.k_T0*a.omega_m_max^2;
angles=[0;20;30;35;40;45];required=2.1./cosd(angles);
requirements=table(angles,required,required/0.9,'VariableNames',{'tilt_deg','required_thrust_kgf_from_measured_hover','minimum_maximum_thrust_kgf_with_10percent_reserve'});
writetable(requirements,fullfile(output_dir,'tilt_thrust_requirements.csv'));
% 速度、倾斜方位和速度方位预先枚举；结果只是冻结竖直支撑能力，未求全六自由度配平。
grid=table();speed_values=[0,1,2,3];tilt_values=0:70;directions=0:90:270;
for speed=speed_values
    for tilt=tilt_values
        for tilt_direction=directions
            b3=[-sind(tilt)*cosd(tilt_direction);-sind(tilt)*sind(tilt_direction);cosd(tilt)];
            R=ca_euler_rotation([asin(-b3(2));atan2(b3(1),b3(3));0]);
            for velocity_direction=directions
                v=speed*[cosd(velocity_direction);sind(velocity_direction);0];
                upward=NaN;axial=NaN;outside=false;
                try
                    out=ca_shc09_aerodynamics(R,v,zeros(3,1),zeros(6,1),a.omega_m_max,m,c);
                    force=R*out.force_body_n;upward=-force(3);axial=out.thrust_n;outside=out.table_extrapolated;
                catch problem
                    if ~strcmp(problem.identifier,'ca:AeroTableDomain'),rethrow(problem);end
                    % 域外组合只记录失败与缺失值；不切换外推策略或使用无效推力数值。
                    outside=true;
                end
                grid=[grid;table(speed,tilt,tilt_direction,velocity_direction,upward,upward/weight,axial,outside, ...
                    'VariableNames',{'speed_m_s','tilt_deg','tilt_direction_deg','velocity_direction_deg','upward_force_n','vertical_support_to_weight','axial_thrust_n','table_extrapolated'})];
            end
        end
    end
end
writetable(grid,fullfile(output_dir,'frozen_force_scan.csv'));
summary=table();
for speed=speed_values
    q=grid.speed_m_s==speed&grid.tilt_deg==45;values=grid.vertical_support_to_weight(q);
    summary=[summary;table(speed,min(values,[],'omitnan'),max(values,[],'omitnan'),sum(grid.table_extrapolated(q)), ...
        'VariableNames',{'speed_m_s','minimum_valid_support_to_weight_at45deg','maximum_valid_support_to_weight_at45deg','domain_invalid_combinations'})];
end
writetable(summary,fullfile(output_dir,'frozen_force_scan_at45deg.csv'));
report=struct('model_weight_n',weight,'static_model_maximum_thrust_n',maximum, ...
    'static_level_height_limit_deg',acosd(weight/maximum), ...
    'static_level_height_limit_with10percent_reserve_deg',acosd(weight/(0.9*maximum)), ...
    'px4_default_air_tilt_deg',45,'model_F8_tilt_cap_deg',45,'rc_stick_hover_fraction',0.7, ...
    'measured_hover_thrust_kgf',2.1,'rc_stick_identifies_maximum_thrust',false, ...
    'maximum_airframe_thrust_measured',false,'frozen_force_scan_cases',height(grid), ...
    'frozen_force_scan_is_full_trim_or_control_authority_proof',false, ...
    'aerodynamic_scan_domain_invalid_present',any(grid.table_extrapolated), ...
    'domain_invalid_combinations_excluded_from_force_statistics',true, ...
    'invalid_upward_force_values_saved_as_nan',all(isnan(grid.upward_force_n(grid.table_extrapolated))), ...
    'protocol_hash',p.frozen_protocol_hash);
fid=fopen(fullfile(output_dir,'checks.json'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));disp(report);disp(summary);
end
