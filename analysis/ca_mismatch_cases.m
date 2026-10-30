function definitions = ca_mismatch_cases(cases,model,protocol)
% 线性档使用列增益；非线性档使用公共名义负载工作点的局部雅可比。
C=model.torque_matrix; inverse=pinv(C); N=eye(6)-inverse*C;
definitions=table(string({cases.id})',string({cases.description})',string({cases.mapping})', ...
    [cases.saturation_deg]','VariableNames',{'case_id','description','map','saturation_deg'});
definitions=[definitions,array2table([cases.gains]','VariableNames',cellstr(compose('gain_%d',1:6)))];
row=zeros(numel(cases),1); null=row; basis=repmat("constant_column_gain",numel(cases),1);
working=protocol.mismatch_working_delta_rad;
for k=1:numel(cases)
    local=cases(k).gains;
    if string(cases(k).mapping)=="tanh"
        local=local.*(1-tanh(working/deg2rad(cases(k).saturation_deg)).^2);
        basis(k)="nominal_load_local_jacobian";
    end
    G=diag(local);
    row(k)=norm(C*G*inverse-eye(3),'fro');
    null(k)=norm(C*(G-eye(6))*N,2);
end
definitions=[definitions,table(row,null,basis,'VariableNames', ...
    {'rowspace_mismatch','nullspace_mismatch','mismatch_basis'}), ...
    array2table(repmat(rad2deg(working)',numel(cases),1),'VariableNames',cellstr(compose('working_delta_deg_%d',1:6)))];
end
