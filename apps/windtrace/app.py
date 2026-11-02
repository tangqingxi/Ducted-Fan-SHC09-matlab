"""WindTrace单飞行.wtr入口；不接受旧MAT或多方法bundle。"""
import argparse
import json
import os
from pathlib import Path
import sys

os.environ.setdefault("QT_API","pyside6")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("flights",nargs="*",type=Path)
    parser.add_argument("--smoke",action="store_true",help="校验容器并输出摘要，不启动GUI")
    parser.add_argument("--no-3d",action="store_true")
    parser.add_argument("--screenshot",type=Path)
    parser.add_argument("--time",type=float,default=0)
    parser.add_argument("--report",type=Path,help="把后台校验摘要写入新的JSON文件")
    parser.add_argument("--panel",choices=['3d','parameters','curves'],default='3d',help="离屏截图的视图")
    parser.add_argument("--search",default='',help="参数截图的搜索字段")
    parser.add_argument("--settings-file",type=Path,help="指定独立的本地设置文件")
    parser.add_argument("--camera-drag",type=int,nargs=2,metavar=('DX','DY'),help="仅截图验证：驱动VTK内部旋转，不移动桌面鼠标")
    args=parser.parse_args()
    if args.camera_drag and not args.screenshot: parser.error('--camera-drag仅用于--screenshot验证')
    if args.screenshot:
        os.environ.setdefault("QT_QPA_PLATFORM","offscreen")
    if args.smoke:
        from core.flight import read_flight
        flights=[read_flight(p) for p in args.flights]
        summary=[{"run_id":f.run_id,"topics":len(f.topics),"parameters":len(f.parameters),"duration_s":f.manifest["duration_s"],"execution":f.manifest["execution"],"audit":f.manifest["audit"]["original"]} for f in flights]
        if args.report:
            with args.report.open('x',encoding='utf-8') as stream: json.dump(summary,stream,ensure_ascii=False,indent=2)
        if sys.stdout is not None: print(json.dumps(summary,ensure_ascii=False,indent=2))
        return 0
    from PySide6 import QtCore,QtGui,QtWidgets
    from ui.main_window import MainWindow
    app=QtWidgets.QApplication(sys.argv[:1]); app.setApplicationName("WindTrace")
    configure_font(app)
    settings=QtCore.QSettings(str(args.settings_file),QtCore.QSettings.Format.IniFormat) if args.settings_file else None
    window=MainWindow(args.no_3d,settings=settings); window.setWindowIcon(QtGui.QIcon(str(Path(__file__).parent/"assets/logo_64.png")))
    window.show(); app.processEvents()
    if args.flights: window.load_async(args.flights,remember=not args.screenshot)
    elif not args.screenshot: QtCore.QTimer.singleShot(0,window.restore_recent)
    if args.screenshot:
        def capture():
            if window.loading:
                QtCore.QTimer.singleShot(100,capture); return
            try:
                if window.flight: window.slider.setValue(round(args.time/window.flight.manifest["duration_s"]*10000))
                if args.camera_drag and window.flight and window.view.plotter is not None:
                    p=window.view.plotter; interactor=p.iren.interactor; style=p.iren.style
                    width,height=p.render_window.GetSize(); x,y=width//2,height//2
                    interactor.SetEventInformation(x,y); style.OnLeftButtonDown()
                    interactor.SetEventInformation(x+args.camera_drag[0],y+args.camera_drag[1]); style.OnMouseMove(); style.OnLeftButtonUp()
                if args.panel=='parameters':
                    window.show_parameters(); window.parameters.search.setText(args.search); app.processEvents()
                    assert window.parameters_dialog.grab().save(str(args.screenshot))
                else:
                    if args.panel=='curves': window.curve_button.setChecked(True); app.processEvents()
                    assert window.screenshot(args.screenshot)
                if args.report:
                    report={'view3d_available':window.view.plotter is not None,'view3d_error':window.view.error,'parameters':window.parameters.table.rowCount(),'visible_parameters':sum(not window.parameters.table.isRowHidden(i) for i in range(window.parameters.table.rowCount())),'parameter_table_readonly':window.parameters.table.editTriggers()==QtWidgets.QAbstractItemView.EditTrigger.NoEditTriggers,'display_options':[window.domain.itemText(i) for i in range(window.domain.count())],'grid_default':window.grid_switch.isChecked(),'reference_default':window.reference_switch.isChecked(),'loaded_flights':len(window.flights),'panel':args.panel}
                    report.update(empty_prompt_visible=window.welcome.isVisible(),play_enabled=window.play.isEnabled(),loading=window.loading,last_error=window.last_error)
                    report.update(welcome_size=[window.welcome.width(),window.welcome.height()],welcome_button_height=window.welcome_open.height())
                    if window.view.plotter is not None:
                        report.update(camera_clipping_range=list(window.view.plotter.camera.clipping_range),grid_actor_visible=[bool(a.GetVisibility()) for a in window.view.grid_actors])
                    with args.report.open('x',encoding='utf-8') as stream: json.dump(report,stream,ensure_ascii=False,indent=2)
            finally:
                window.parameters_dialog.close(); window.close(); app.quit()
        QtCore.QTimer.singleShot(1500,capture)
    return app.exec()


def configure_font(app):
    from PySide6 import QtGui
    # Windows离屏插件不总会枚举系统字体，显式加载现有字体以保证中文可读。
    font=Path(os.environ.get("WINDIR","C:/Windows"))/"Fonts/msyh.ttc"
    if font.is_file():
        identifier=QtGui.QFontDatabase.addApplicationFont(str(font))
        families=QtGui.QFontDatabase.applicationFontFamilies(identifier)
        if families: app.setFont(QtGui.QFont(families[0],10))


if __name__=="__main__": raise SystemExit(main())
