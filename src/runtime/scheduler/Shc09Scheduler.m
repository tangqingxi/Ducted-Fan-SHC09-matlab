classdef Shc09Scheduler < handle
    % 确定性单线程时钟；事件通过整数序号除以频率定位，不累计浮点步长。
    properties (Access=private)
        pwm_hz
        pwm_phase_s
        pwm_index=0
        groups=struct('name',{},'hz',{},'priority',{},'callback',{})
    end
    methods
        function obj=Shc09Scheduler(sample_hz,pwm_hz,phase)
            if nargin<3,phase=0;end
            assert(sample_hz>0 && pwm_hz>0 && pwm_hz<=sample_hz && phase>=0,'时钟配置错误。');
            obj.pwm_hz=pwm_hz;obj.pwm_phase_s=phase;
        end
        function value=next_pwm_time(obj)
            value=obj.pwm_phase_s+obj.pwm_index/obj.pwm_hz;
        end
        function advance_pwm(obj)
            obj.pwm_index=obj.pwm_index+1;
        end
        function value=next_boundary(obj,interval_end)
            value=min(interval_end,obj.next_pwm_time());
        end
        function add_rate_group(obj,name,hz,priority,callback)
            if nargin<5,callback=[];end
            assert(hz>0 && isfinite(hz) && ~any(strcmp({obj.groups.name},name)),'速率组错误。');
            obj.groups(end+1)=struct('name',char(name),'hz',hz,'priority',priority,'callback',callback);
        end
        function trace=run(obj,duration_s)
            rows={};indices=zeros(1,numel(obj.groups));
            while ~isempty(obj.groups)
                times=indices./[obj.groups.hz];next=min(times);
                if next>duration_s+1e-11,break;end
                active=find(abs(times-next)<1e-11);[~,order]=sort([obj.groups(active).priority],'descend');
                for index=active(order)
                    group=obj.groups(index);rows(end+1,:)={group.name,next,group.priority}; %#ok<AGROW>
                    if ~isempty(group.callback),group.callback(next);end
                    indices(index)=indices(index)+1;
                end
            end
            trace=cell2table(rows,'VariableNames',{'group','time_s','priority'});
        end
    end
end
