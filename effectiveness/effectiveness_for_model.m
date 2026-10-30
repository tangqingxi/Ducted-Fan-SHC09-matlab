function nominal = effectiveness_for_model(model,cfg)
% 根据名义飞行器标识选择效能，不按分配方法分支。
entries=effectiveness_registry();index=find(strcmp({entries.plant_model},string(model.plant_model)),1);
assert(~isempty(index),'shc09:UnknownEffectiveness','飞行器效能未注册。');
nominal=entries(index).factory(model,cfg);
end
