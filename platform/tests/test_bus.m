function test_bus()
% 覆盖最新覆盖、时间戳、订阅和时间倒退的确定行为。
bus=Shc09Bus();assert(~bus.exists('a'));bus.publish('a',[1;2],0);
[a,t,s]=bus.subscribe('a');assert(isequal(a,[1;2]) && t==0 && s==1);
bus.publish('a',3,0);assert(bus.latest('a')==3 && bus.timestamp('a')==0);
rejected=false;try,bus.publish('a',4,-1);catch,rejected=true;end
assert(rejected && bus.latest('a')==3);
end
