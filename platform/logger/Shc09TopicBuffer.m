classdef Shc09TopicBuffer < handle
    % 每个topic独立扩容，避免每次发布复制整段历史。
    properties (Access=private)
        times
        sequences
        payloads
        count=0
    end
    methods
        function obj=Shc09TopicBuffer(capacity)
            obj.times=zeros(capacity,1);obj.sequences=zeros(capacity,1,'uint64');obj.payloads=cell(capacity,1);
        end
        function append(obj,payload,time_s,sequence)
            if obj.count==numel(obj.times)
                capacity=max(16,2*numel(obj.times));obj.times(capacity,1)=0;
                obj.sequences(capacity,1)=uint64(0);obj.payloads{capacity,1}=[];
            end
            obj.count=obj.count+1;obj.times(obj.count)=time_s;
            obj.sequences(obj.count)=sequence;obj.payloads{obj.count}=payload;
        end
        function value=snapshot(obj)
            value=struct('time_s',obj.times(1:obj.count),'sequence',obj.sequences(1:obj.count), ...
                'data',{obj.payloads(1:obj.count)});
        end
    end
end
