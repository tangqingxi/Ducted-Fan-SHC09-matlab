"""只消费.wtr中已转换的FRD网格和姿态，不再执行SHC09坐标变换。"""
import os
import numpy as np
from PySide6 import QtWidgets
from scipy.spatial.transform import Rotation
from ui import theme

NED_TO_ENU = np.array([[0.,1.,0.],[1.,0.,0.],[0.,0.,-1.]])


class ReplayView3D(QtWidgets.QWidget):
    def __init__(self, disabled=False):
        super().__init__(); self.plotter=None; self.error=""; self.flight=None; self.actors=[]
        self.grid_visible=True; self.reference_visible=False; self.grid_actors=[]; self.reference_actors=[]
        self.camera_follow=True; self._last_position=None
        self.offscreen=os.environ.get("QT_QPA_PLATFORM")=="offscreen"
        self.badge=QtWidgets.QLabel(self); self.badge.setObjectName('viewOverlay'); self.badge.hide()
        self.layout=QtWidgets.QVBoxLayout(self); self.layout.setContentsMargins(0,0,0,0)
        if disabled:
            self.layout.addWidget(QtWidgets.QLabel("3D已禁用；参数与曲线仍可读取。")); return
        try:
            import pyvista as pv
            self.pv=pv
            if self.offscreen:
                self.plotter=pv.Plotter(off_screen=True,window_size=(1400,760)); self.surface=self
                self.layout.addWidget(QtWidgets.QLabel("后台离屏三维渲染"))
            else:
                from pyvistaqt import QtInteractor
                self.plotter=QtInteractor(self,multi_samples=0,auto_update=False); self.surface=self.plotter.interactor
                self.layout.addWidget(self.surface)
            self.plotter.set_background(theme.COLORS['bg'])
            # 网格不参与机体取景边界，交互器不能仅按机体边界收缩裁剪面。
            style=self.plotter.iren.style
            style.AutoAdjustCameraClippingRangeOff()
            self._interaction_observer=style.AddObserver('InteractionEvent',self.update_clipping_range)
        except Exception as problem:
            self.error=str(problem); self.layout.addWidget(QtWidgets.QLabel("3D不可用："+self.error))

    def set_flight(self, flight, domain):
        self.flight=flight; self.domain=domain
        if self.plotter is None: return
        p=self.plotter; p.clear(); self.actors=[]
        self._last_position=None
        self.grid_actors=[]; self.reference_actors=[]
        p.add_axes(xlabel="E",ylabel="N",zlabel="U")
        position_topic="trajectory_setpoint" if domain=="reference" else "vehicle_local_position"+("_groundtruth" if domain=="truth" else "")
        self.pose_time=flight.time(position_topic)
        self.position=flight.position(position_topic)@NED_TO_ENU.T
        att="vehicle_attitude_reference" if domain=="reference" else "vehicle_attitude"+("_groundtruth" if domain=="truth" else "")
        self.att_time=flight.time(att)
        q=flight.field(att,"q"); self.rotations=NED_TO_ENU@Rotation.from_quat(q[:,[1,2,3,0]]).as_matrix()
        self.add_ground_grid()
        # 三维只保留可选的规划参考，不绘制真实或估计轨迹。
        for topic,color,label in [("trajectory_setpoint",theme.COLORS['reference'],"参考轨迹")]:
            points=flight.position(topic)@NED_TO_ENU.T
            stride=max(1,len(points)//4000); points=points[::stride]
            if np.linalg.norm(np.ptp(points,axis=0))>1e-9:
                actor=p.add_mesh(self.pv.lines_from_points(points),color=color,line_width=1.5,label=label)
            else:
                actor=p.add_points(points[:1],color=color,point_size=6,label=label,render_points_as_spheres=True)
            actor.SetVisibility(self.reference_visible); actor.SetUseBounds(False); self.reference_actors.append(actor)
        meshes=flight.geometry["meshes"]
        body=self.pv.PolyData(np.asarray(meshes["body"]["points"]),np.asarray(meshes["body"]["faces"]))
        codes=np.asarray(meshes["body"].get("part",[]))
        if len(codes)==body.n_points:
            # 网格分类编号沿用原解析器：0涵道、1机身、2转子、3脚架；不能按名称直觉反转。
            body.compute_normals(cell_normals=False,point_normals=True,auto_orient_normals=True,inplace=True)
            light=np.array([-.40,-.35,-.85]); light/=np.linalg.norm(light)
            dot=np.clip(np.asarray(body.point_data.active_normals)@light,0,1)
            shade=np.where(codes==0,.88+.12*dot,.68+.36*dot)
            palette=np.array([list(bytes.fromhex(theme.MODEL_COLORS[key].lstrip('#'))) for key in ['duct','body','rotor','leg']],dtype=float)
            body.point_data['rgb']=np.clip(np.rint(palette[codes.astype(int)]*shade[:,None]),0,255).astype(np.uint8)
            actor=p.add_mesh(body,scalars="rgb",rgb=True,smooth_shading=True,lighting=False,show_scalar_bar=False)
        else: actor=p.add_mesh(body,color=theme.MODEL_COLORS['body'],lighting=False)
        self.actors.append(actor)
        for part in meshes["vanes"]:
            mesh=self.pv.PolyData(np.asarray(part["points"]),np.asarray(part["faces"]))
            self.actors.append(p.add_mesh(mesh,color=theme.MODEL_COLORS['vane'],smooth_shading=True,show_edges=True,edge_color=theme.MODEL_COLORS['duct'],line_width=.7,lighting=False))
        vane_note="actual vanes" if domain=="truth" else "estimated vanes"
        if domain=="reference": vane_note="reference pose; no actuator reference"
        p.view_isometric(); self.set_time(0); self.frame_vehicle(); p.render()
        # QtInteractor没有公开的off_screen属性，使用本视图选定的渲染模式。
        if self.offscreen: p.show(auto_close=False,interactive=False)

    def add_ground_grid(self):
        # 沿用原版地面网格：世界ENU高度0，1m细线／5m主线，远处淡出；不改变相机取景范围。
        for step,half,color,width in [(1.,70.,theme.COLORS['grid_minor'],1.),(5.,100.,theme.COLORS['grid_major'],1.2)]:
            segments=[]
            for value in np.arange(-half,half+.5,step):
                if step==1 and abs(value/5-round(value/5))<1e-9: continue
                segments.extend([[(value,-half,0),(value,half,0)],[(-half,value,0),(half,value,0)]])
            points=np.asarray(segments).reshape(-1,3); cells=np.column_stack([np.full(len(segments),2),np.arange(0,len(points),2),np.arange(1,len(points),2)]).ravel()
            mesh=self.pv.PolyData(points,lines=cells)
            rgba=np.empty((len(points),4),dtype=np.uint8); rgba[:,:3]=list(bytes.fromhex(color.lstrip('#')))
            rgba[:,3]=np.rint((1-np.clip((np.hypot(points[:,0],points[:,1])-40)/140,0,1))*255).astype(np.uint8)
            mesh.point_data['grid_rgba']=rgba
            actor=self.plotter.add_mesh(mesh,scalars='grid_rgba',rgb=True,line_width=width,show_scalar_bar=False,lighting=False)
            actor.SetVisibility(self.grid_visible); actor.SetUseBounds(False); self.grid_actors.append(actor)

    def set_grid_visible(self, visible):
        self.grid_visible=bool(visible)
        for actor in self.grid_actors: actor.SetVisibility(self.grid_visible)
        if self.plotter: self.plotter.render()

    def set_reference_visible(self, visible):
        self.reference_visible=bool(visible)
        for actor in self.reference_actors: actor.SetVisibility(self.reference_visible)
        if self.plotter: self.plotter.render()

    def set_camera_follow(self, enabled):
        self.camera_follow=bool(enabled)
        if self.camera_follow and self.plotter is not None and self._last_position is not None:
            center=self._last_position; camera=self.plotter.camera
            offset=center-np.asarray(camera.focal_point)
            camera.position=np.asarray(camera.position)+offset; camera.focal_point=center
            self.update_clipping_range()
            self.plotter.render()

    def update_clipping_range(self,*_):
        if self.plotter is None: return
        # 覆盖原点附近的完整地面网格；拉远相机时同步增加远裁剪距离。
        far=max(500.,float(np.linalg.norm(self.plotter.camera.position))+200.)
        self.plotter.camera.SetClippingRange(.05,far)

    def frame_vehicle(self):
        if self.plotter is None or self.flight is None: return
        center=self.position[getattr(self,'pose_index',0)]
        span=max(float(self.flight.geometry['vehicle']['body_box_m'][2]),.6)
        distance=span/(2*.32*np.tan(np.deg2rad(self.plotter.camera.view_angle/2)))
        direction=np.array([1.,-1.1,-.10]); direction/=np.linalg.norm(direction)
        self.plotter.camera_position=[center+direction*distance,center,(0,0,1)]
        self.update_clipping_range(); self.plotter.render()

    def frame_overview(self):
        if self.plotter is None: return
        self.plotter.view_isometric(); self.plotter.reset_camera(); self.update_clipping_range(); self.plotter.render()

    def set_time(self, time):
        if self.plotter is None or self.flight is None: return
        k=max(0,min(len(self.pose_time)-1,int(np.searchsorted(self.pose_time,time,side="right")-1)))
        j=max(0,min(len(self.att_time)-1,int(np.searchsorted(self.att_time,time,side="right")-1)))
        self.pose_index=k
        label={'truth':'真实状态','estimate':'估计状态','reference':'规划参考'}[self.domain]
        self.badge.setText(f"{self.flight.manifest['method']} · {label} · {time:.3f} s"); self.badge.adjustSize(); self.badge.move(48,12); self.badge.show(); self.badge.raise_()
        R=self.rotations[j]; pos=self.position[k]; matrix=np.eye(4); matrix[:3,:3]=R; matrix[:3,3]=pos
        # 仅跟随平移，保留观察角度；不随飞机偏航旋转，也不改变飞行状态。
        if self.camera_follow and self._last_position is not None:
            delta=pos-self._last_position; camera=self.plotter.camera
            camera.position=np.asarray(camera.position)+delta; camera.focal_point=np.asarray(camera.focal_point)+delta
        self._last_position=pos.copy()
        self.actors[0].user_matrix=matrix
        f=self.flight; topic="shc09_vanes"; vtime=f.time(topic)
        n=max(0,min(len(vtime)-1,int(np.searchsorted(vtime,time,side="right")-1)))
        values=f.field(topic,"actual" if self.domain=="truth" else "estimated")[n]
        for i,part in enumerate(f.geometry["meshes"]["vanes"]):
            self.actors[i+1].visibility=self.domain!="reference"
            matrix=np.eye(4); matrix[:3,:3]=R@Rotation.from_rotvec(np.asarray(part["axis"])*values[i]).as_matrix()
            matrix[:3,3]=pos+R@np.asarray(part["center"])
            self.actors[i+1].user_matrix=matrix
        # 更新相机位置时VTK会根据尚未移动的旧网格重算裁剪面；完成位姿更新后统一恢复。
        self.update_clipping_range()
        self.plotter.render()

    def closeEvent(self,event):
        if self.plotter: self.plotter.close()
        super().closeEvent(event)
