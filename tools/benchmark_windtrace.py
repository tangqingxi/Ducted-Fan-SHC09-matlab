"""后台测量真实姿态更新与VTK渲染；不把计时器设置当作实测帧率。"""
import argparse
import json
import os
from pathlib import Path
import sys
import time

os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'apps/windtrace'))
import numpy as np
from PySide6 import QtWidgets
from ui.main_window import MainWindow
from app import configure_font


def measure(window,count,curves):
    window.curve_button.setChecked(curves); app=QtWidgets.QApplication.instance(); app.processEvents()
    duration=window.flight.manifest['duration_s']; samples=[]
    for i,t in enumerate(np.linspace(0,duration,count+12)):
        start=time.perf_counter_ns(); window.slider.setValue(round(t/duration*10000)); app.processEvents()
        elapsed=(time.perf_counter_ns()-start)/1e6
        if i>=12: samples.append(elapsed)
    return {'frames':len(samples),'curve_drawer_open':curves,'mean_ms':float(np.mean(samples)),'p50_ms':float(np.percentile(samples,50)),'p95_ms':float(np.percentile(samples,95)),'max_ms':float(np.max(samples)),'above_16_67_ms':sum(x>1000/60 for x in samples),'render_capacity_fps':1000/float(np.mean(samples)),'frame_ms':samples}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('flight',type=Path); parser.add_argument('report',type=Path); parser.add_argument('--frames',type=int,default=300)
    args=parser.parse_args(); assert args.frames>20 and not args.report.exists()
    app=QtWidgets.QApplication([]); configure_font(app); window=MainWindow(); start=time.perf_counter()
    window.load([args.flight]); window.show(); app.processEvents(); window.timer.stop(); load_seconds=time.perf_counter()-start
    try:
        assert window.view.plotter is not None,window.view.error
        results=[measure(window,args.frames,False),measure(window,args.frames,True)]
        capabilities=window.view.plotter.render_window.ReportCapabilities()
        report={'backend':'offscreen Qt + VTK, synchronous render; not desktop presentation FPS','window':[window.width(),window.height()],'load_seconds':load_seconds,'results':results,'gpu':[line.strip() for line in capabilities.splitlines() if 'OpenGL renderer' in line or 'OpenGL vendor' in line]}
        with args.report.open('x',encoding='utf-8') as stream: json.dump(report,stream,indent=2)
        print(json.dumps({**report,'results':[{k:v for k,v in r.items() if k!='frame_ms'} for r in results]},indent=2))
    finally: window.close(); app.processEvents()
