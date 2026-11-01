function report = test_figure8_reference()
% 验证闭合八字及解析导数，确保未把几何速度当成位置环已使用的前馈。
c=ca_config();c.duration_s=52;[r,p]=ca_figure8_reference(c);t=r.time_s;dt=1/c.sample_hz;
assert(isequal(size(r.position_ned_m),[41601,3]));
assert(max(abs(r.position_ned_m(:,3)+10))==0);
assert(max(abs(r.position_ned_m(1,:)-r.position_ned_m(end,:)))<1e-12);
assert(max(abs(r.velocity_ned_m_s([1,end],:)),[],'all')==0);
assert(max(abs(r.acceleration_ned_m_s2([1,end],:)),[],'all')==0);
velocity=(r.position_ned_m(3:end,:)-r.position_ned_m(1:end-2,:))/(2*dt);
acceleration=(r.velocity_ned_m_s(3:end,:)-r.velocity_ned_m_s(1:end-2,:))/(2*dt);
assert(max(abs(velocity-r.velocity_ned_m_s(2:end-1,:)),[],'all')<2e-6);
assert(max(abs(acceleration-r.acceleration_ned_m_s2(2:end-1,:)),[],'all')<2e-6);
assert(all(r.position_ned_m(t<=6,1:2)==0,'all'));
assert(isequal(p.evaluation_window_s,[6,50])&&isequal(p.cruise_window_s,[10,46]));
assert(p.command_limit_deg==40&&p.load_fraction==0.6);
report=struct('samples',numel(t),'duration_s',52,'closed',true,'analytic_derivatives_checked',true);
fprintf('八字参考闭合、解析导数、时间窗与40度限幅声明检查通过。\n');
end
