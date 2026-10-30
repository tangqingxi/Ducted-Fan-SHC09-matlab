classdef Shc09Params < handle
    % 声明式参数容器；更新先验证，失败不改变当前参数。
    properties (Access=private)
        values=struct()
        validators=struct()
        global_validator=[]
        history=struct('name',{},'time_s',{},'old_value',{},'value',{})
    end
    methods
        function obj=Shc09Params(values,validator)
            if nargin>=1,obj.values=values;end
            if nargin>=2,obj.global_validator=validator;end
            obj.validate();
        end
        function declare(obj,name,value,validator)
            if nargin<4,validator=[];end
            name=char(name);assert(isvarname(name) && ~isfield(obj.values,name),'shc09:ParameterDeclaration','参数名已声明或非法。');
            if ~isempty(validator),assert(validator(value),'shc09:ParameterValue','参数校验失败。');end
            obj.values.(name)=value;obj.validators.(name)=validator;
        end
        function value=get(obj,name)
            assert(isfield(obj.values,name),'shc09:UnknownParameter','参数未声明：%s',name);value=obj.values.(name);
        end
        function set(obj,name,value,time_s)
            if nargin<4,time_s=0;end
            name=char(name);old=obj.get(name);
            if isfield(obj.validators,name) && ~isempty(obj.validators.(name))
                assert(obj.validators.(name)(value),'shc09:ParameterValue','参数校验失败。');
            end
            candidate=obj.values;candidate.(name)=value;
            if ~isempty(obj.global_validator),candidate=obj.global_validator(candidate);end
            obj.values=candidate;obj.history(end+1)=struct('name',name,'time_s',time_s,'old_value',old,'value',value);
        end
        function validate(obj)
            if ~isempty(obj.global_validator),obj.values=obj.global_validator(obj.values);end
        end
        function value=snapshot(obj)
            value=obj.values;
        end
        function value=log(obj)
            value=obj.history;
        end
    end
end
