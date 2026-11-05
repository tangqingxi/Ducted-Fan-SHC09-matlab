function method = ca_allocator_name(flag)
% 统一分配器选择标志：一至五，或使用同名字符串。
methods=["DA_NS","WLS","DCA","PCA_STATIC","PCA_PREDICTIVE"];
if isnumeric(flag)
    assert(isscalar(flag) && isfinite(flag) && flag==fix(flag) && flag>=1 && flag<=5,'分配器标志须为一至五。');
    method=methods(flag);
else
    method=upper(string(flag));
    registered=registry();
    assert(isscalar(method) && ismember(method,[registered.name]),'未知分配器名称。');
end
end
