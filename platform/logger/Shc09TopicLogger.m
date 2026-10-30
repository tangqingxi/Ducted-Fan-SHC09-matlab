classdef Shc09TopicLogger < handle
    % 只记录总线发布的值结构；物理真值仍由sim私有旧日志保存。
    properties (Access=private)
        buffers
        capacity
    end
    methods
        function obj=Shc09TopicLogger(capacity)
            if nargin<1,capacity=256;end
            obj.capacity=max(1,ceil(capacity));obj.buffers=containers.Map('KeyType','char','ValueType','any');
        end
        function record(obj,name,payload,time_s,sequence)
            name=char(name);
            if ~isKey(obj.buffers,name),obj.buffers(name)=Shc09TopicBuffer(obj.capacity);end
            buffer=obj.buffers(name);buffer.append(payload,time_s,sequence);
        end
        function value=snapshot(obj)
            value=struct();names=sort(keys(obj.buffers));
            for k=1:numel(names),buffer=obj.buffers(names{k});value.(names{k})=buffer.snapshot();end
        end
    end
end
