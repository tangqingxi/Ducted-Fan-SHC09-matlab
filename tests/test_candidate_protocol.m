function test_candidate_protocol()
% 独立检查八字几何恒等式、完整两圈和平滑起停，避免只检查绘图外观。
ca_setup();
for fraction=[0.8,0.98]
    for name=["figure8_T8","figure8_T12","hover_turning"]
        [cfg,~,ref,p]=ca_candidate_protocol(name,20261029,fraction);
        position=ref.position_ned_m;
        assert(norm(position(1,:)-[0,0,-10],Inf)<1e-12 && norm(position(end,:)-[0,0,-10],Inf)<1e-10, ...
            '候选参考没有从悬停点平滑回到悬停点。');
        assert(p.load_fraction==fraction && all(cfg.wls_axis_weights==1),'公共占用或等轴权重错误。');
        if p.kind=="figure8"
            x=position(:,1)/2; y=position(:,2);
            assert(max(abs(y.^2-4*x.^2.*(1-x.^2)))<1e-12,'八字几何关系错误。');
            assert(sum(diff(x>1e-6)==1)==2,'没有完整走两圈。');
            velocity=diff(position)*cfg.sample_hz;
            assert(norm(velocity(1,:))<1e-9 && norm(velocity(end,:))<1e-9,'起停速度不为零。');
        else
            assert(max(vecnorm(position-[0,0,-10],2,2))<1e-12,'定点工况参考位置变化。');
        end
    end
end
fprintf('两种负载、两条八字几何与圈数及定点协议检查通过。\n');
end
