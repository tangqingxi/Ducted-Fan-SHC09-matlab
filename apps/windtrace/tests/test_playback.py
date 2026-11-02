"""播放按真实经过时间推进，不随帧率和整数滑块产生累计漂移。"""
import os
from PySide6 import QtWidgets
import pytest
from ui.main_window import MainWindow


def test_wall_clock_without_rounding_drift(monkeypatch):
    source=os.environ.get('WINDTRACE_TEST_FLIGHTS','').split(os.pathsep)[0]
    if not source: pytest.skip('集成运行提供真实.wtr')
    app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window=MainWindow(no_3d=True); window.load([source]); window.timer.stop()
    clock=[100.]; monkeypatch.setattr('ui.main_window.time.monotonic',lambda:clock[0])
    window.toggle_play()
    for i in range(601):
        clock[0]=100+i/60; window.advance()
    assert window._current_time==pytest.approx(10,abs=.004)
    assert window.slider.value()==2500
    window.toggle_play(); window.close(); app.processEvents()
