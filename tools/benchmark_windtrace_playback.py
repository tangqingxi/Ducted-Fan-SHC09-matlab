"""用真实Qt计时循环测量播放节奏；后台完成，结果不代表桌面呈现帧率。"""
import json
import os
from pathlib import Path
import sys
import time

os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'apps/windtrace'))
import numpy as np
from PySide6 import QtWidgets,QtCore
from ui.main_window import MainWindow
from app import configure_font


def run(window,interval,curves):
    window.playing=False; window.slider.setValue(0); window.curve_button.setChecked(curves)
    window.timer.setInterval(interval); app=QtWidgets.QApplication.instance(); app.processEvents()
    render_times=[]; cursor_times=[]
    observer=window.view.plotter.render_window.AddObserver('EndEvent',lambda *_:render_times.append(time.perf_counter()))
    on_cursor=lambda *_:cursor_times.append(time.perf_counter())
    window.cursor.sigPositionChanged.connect(on_cursor)
    loop=QtCore.QEventLoop(); started=time.perf_counter(); window.toggle_play()
    QtCore.QTimer.singleShot(5000,loop.quit); loop.exec(); elapsed=time.perf_counter()-started
    window.playing=False; window.timer.stop(); window.view.plotter.render_window.RemoveObserver(observer); window.cursor.sigPositionChanged.disconnect(on_cursor)
    gaps=np.diff(render_times)*1000
    return {'interval_ms':interval,'curves_open':curves,'elapsed_s':elapsed,'renders':len(render_times),'updates_per_s':len(render_times)/elapsed,'frame_gap_p50_ms':float(np.percentile(gaps,50)),'frame_gap_p95_ms':float(np.percentile(gaps,95)),'cursor_updates':len(cursor_times),'mission_time_s':window._current_time,'clock_error_s':window._current_time-elapsed}


if __name__=='__main__':
    source,report=map(Path,sys.argv[1:]); assert not report.exists()
    app=QtWidgets.QApplication([]); configure_font(app); window=MainWindow(); window.load([source]); window.show(); app.processEvents()
    try:
        records=[]
        for interval,curves in [(33,False),(33,True),(16,False),(16,True)]:
            window.timer.start(); records.append(run(window,interval,curves))
        data={'backend':'offscreen Qt+VTK real event loop; same optimized renderer, cadence comparison only; not original app or desktop presentation FPS','records':records}
        with report.open('x',encoding='utf-8') as stream: json.dump(data,stream,indent=2)
        print(json.dumps(data,indent=2))
    finally: window.close(); app.processEvents()
