"""回放中的位置变化不能使飞机飞出近景，跟随也不能改变观察角度。"""
import os
import numpy as np
import pytest
from PySide6 import QtWidgets
from ui.main_window import MainWindow


def test_follow_translation_and_free_view():
    source=os.environ.get('WINDTRACE_TEST_FLIGHTS','').split(os.pathsep)[0]
    if not source: pytest.skip('集成运行提供真实.wtr')
    app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window=MainWindow(); window.load([source]); window.timer.stop()
    try:
        assert window.view.plotter is not None,window.view.error
        camera=window.view.plotter.camera
        before=np.asarray(camera.focal_point); offset=np.asarray(camera.position)-before
        old_position=window.view._last_position.copy()
        window.slider.setValue(5000)
        np.testing.assert_allclose(np.asarray(camera.focal_point)-before,window.view._last_position-old_position,atol=1e-12)
        np.testing.assert_allclose(np.asarray(camera.position)-np.asarray(camera.focal_point),offset,atol=1e-12)
        renderer=window.view.plotter.renderer
        renderer.SetWorldPoint(*window.view._last_position,1); renderer.WorldToDisplay()
        assert 0<renderer.GetDisplayPoint()[2]<1
        window.follow_switch.setChecked(False); fixed=np.asarray(camera.focal_point)
        window.slider.setValue(7500)
        np.testing.assert_allclose(camera.focal_point,fixed,atol=1e-12)
    finally: window.close(); app.processEvents()


def test_drag_and_zoom_keep_ground_grid_unclipped():
    source=os.environ.get('WINDTRACE_TEST_FLIGHTS','').split(os.pathsep)[0]
    if not source: pytest.skip('集成运行提供真实.wtr')
    app=QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window=MainWindow(); window.load([source]); window.timer.stop()
    try:
        view=window.view; p=view.plotter; interactor=p.iren.interactor; style=p.iren.style
        # 直接驱动VTK内部事件，复现真实左键轨迹球旋转，不注入桌面鼠标。
        interactor.SetEventInformation(700,380); style.OnLeftButtonDown()
        interactor.SetEventInformation(725,400); style.OnMouseMove(); style.OnLeftButtonUp()
        assert p.camera.clipping_range[1]>=500
        assert all(actor.GetVisibility() for actor in view.grid_actors)
        with_grid=p.screenshot(return_img=True)
        view.set_grid_visible(False); without_grid=p.screenshot(return_img=True)
        assert np.count_nonzero(np.any(with_grid!=without_grid,axis=2))>100
        view.set_grid_visible(True)
        assert all(actor.GetVisibility() for actor in view.grid_actors)
        # 拉远相机后仍需包住地面，而不是只维持固定的500米远裁剪面。
        center=np.asarray(p.camera.focal_point); offset=np.asarray(p.camera.position)-center
        p.camera.position=center+offset*400; style.InvokeEvent('InteractionEvent')
        assert p.camera.clipping_range[1]>np.linalg.norm(p.camera.position)+150
        view.frame_overview(); assert p.camera.clipping_range[1]>=500
        view.frame_vehicle(); assert p.camera.clipping_range[1]>=500
    finally: window.close(); app.processEvents()
