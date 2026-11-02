"""覆盖双击空启动、后台读入、失败恢复及最近文件，避免把空白当成已加载。"""
import os
import threading
import time

import pytest
from PySide6 import QtCore,QtWidgets
import ui.main_window as module
from ui.main_window import MainWindow


def pump(app,predicate):
    deadline=time.monotonic()+8
    while not predicate() and time.monotonic()<deadline:
        app.processEvents(); time.sleep(.005)
    assert predicate()


def new_window(tmp_path):
    app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    settings=QtCore.QSettings(str(tmp_path/'settings.ini'),QtCore.QSettings.Format.IniFormat)
    window=MainWindow(no_3d=True,settings=settings); window.show(); app.processEvents()
    return app,window


def sources():
    value=os.environ.get('WINDTRACE_TEST_FLIGHTS','')
    if not value: pytest.skip('集成运行提供真实.wtr')
    return value.split(os.pathsep)


def test_empty_window_explains_and_blocks_playback(tmp_path):
    app,window=new_window(tmp_path)
    try:
        assert window.welcome.isVisible() and '打开' in window.welcome_title.text()
        assert not window.play.isEnabled() and not window.slider.isEnabled()
        assert not window.timer.isActive()
        window.toggle_play(); window.curve_button.toggle(); app.processEvents()
        assert not window.playing and not window.curve_drawer.isVisible()
        assert window.open_button.isEnabled() and window.welcome_open.isVisible()
        assert window.welcome.width()==420 and window.welcome.height()<200
        assert window.welcome_open.height()>=44
    finally: window.close(); app.processEvents()


def test_background_load_keeps_event_loop_responsive(tmp_path,monkeypatch):
    path=sources()[0]; app,window=new_window(tmp_path); gate=threading.Event(); original=module.read_flight
    def slow_read(path):
        assert gate.wait(5)
        return original(path)
    monkeypatch.setattr(module,'read_flight',slow_read)
    try:
        window.load_async([path]); assert window.loading and window.load_progress.isVisible()
        assert not window.play.isEnabled() and not window.open_button.isEnabled()
        heartbeat=[]; QtCore.QTimer.singleShot(20,lambda:heartbeat.append(True))
        pump(app,lambda:bool(heartbeat)); assert window.loading
        gate.set(); pump(app,lambda:not window.loading)
        assert window.flight is not None and not window.welcome.isVisible()
        assert window.play.isEnabled() and window.last_error==''
        assert window.settings.value('recent_file')==str(window.flight.path.resolve())
    finally: gate.set(); window.close(); app.processEvents()


def test_failed_open_keeps_previous_flight_and_allows_retry(tmp_path):
    path=sources()[0]; app,window=new_window(tmp_path); bad=tmp_path/'broken.wtr'; bad.write_bytes(b'broken')
    try:
        window.load_async([path]); pump(app,lambda:not window.loading); previous=window.flight
        window.load_async([bad]); pump(app,lambda:not window.loading)
        assert window.flight is previous and window.last_error
        assert window.welcome_title.text()=='日志未能打开' and window.open_button.isEnabled()
        assert window.settings.value('recent_file')==str(previous.path.resolve())
        window.load_async([path]); pump(app,lambda:not window.loading)
        assert not window.last_error and not window.welcome.isVisible()
    finally: window.close(); app.processEvents()


def test_new_selection_and_restore_recent(tmp_path):
    paths=sources(); app,window=new_window(tmp_path)
    try:
        window.load_async([paths[0]]); pump(app,lambda:not window.loading)
        window.load_async([paths[1]]); pump(app,lambda:not window.loading)
        assert window.flight.manifest['method']=='DA_NS'
        recent=window.settings.value('recent_file')
        restored=MainWindow(no_3d=True,settings=window.settings)
        try:
            restored.restore_recent(); pump(app,lambda:not restored.loading)
            assert restored.flight is not None and str(restored.flight.path.resolve())==recent
        finally: restored.close()
    finally: window.close(); app.processEvents()
