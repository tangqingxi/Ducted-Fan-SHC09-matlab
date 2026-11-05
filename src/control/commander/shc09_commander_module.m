function status = shc09_commander_module(bus,command,time_s)
% 最小指令状态机；旧实验以armed状态启动，保持原有行为。
if bus.exists('vehicle_status'),status=bus.latest('vehicle_status');
else,status=struct('armed',true,'mode',"attitude",'failsafe',false);end
for field=["armed","mode","failsafe"]
    if isfield(command,field),status.(field)=command.(field);end
end
if status.failsafe,status.armed=false;end
bus.publish('vehicle_status',status,time_s);
end
