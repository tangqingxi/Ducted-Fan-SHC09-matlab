"""将继承的示意模型一次转换为FRD网格，交付物不依赖外部GLB。"""
import numpy as np


def attach_meshes(geometry):
    from ui.glb_model import load_glb_parts, model_path
    parts = load_glb_parts(model_path())
    C = np.array([[0.,1.,0.],[-1.,0.,0.],[0.,0.,1.]])

    def encode(mesh):
        return {"points":(np.asarray(mesh.points)@C.T).tolist(),"faces":np.asarray(mesh.faces).tolist(),
                "part":np.asarray(mesh.point_data.get("part",[])).tolist()}

    body=parts.body.copy()
    if parts.rotor is not None:
        rotor=parts.rotor.copy(); rotor.points=rotor.points+parts.rotor_center
        rotor.point_data["part"]=np.full(rotor.n_points,2,dtype=np.uint8)
        body=body.merge(rotor,merge_points=False)
    geometry["meshes"] = {"body":encode(body),"vanes":[]}
    hinges = np.asarray(geometry["vehicle"]["hinges_m"])
    candidates = list(parts.vanes)
    # 按原生V1–V6径向方向一一对应示意舵面，不沿用旧GUI的角度排序。
    for target in hinges:
        scores = [np.dot((v.center@C.T)[:2],target[:2])/(np.linalg.norm(v.center[:2])*np.linalg.norm(target[:2])) for v in candidates]
        vane = candidates.pop(int(np.argmax(scores)))
        geometry["meshes"]["vanes"].append({**encode(vane.mesh),"center":(vane.center@C.T).tolist(),"axis":(vane.axis@C.T).tolist()})
    geometry["visual_note"] = "继承Hawkeye示意网格；舵面轴为显示假设，不代表气动效能或实测铰链。静态转子不模拟真实转速。"
    return geometry
