"""短时离屏检查55秒单飞行的起飞、悬停、扰动、恢复与保持；不控制桌面。"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('batch')
    parser.add_argument('--live-only', action='store_true', help='另行核验实际播放推进，不重复五阶段截图')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    delivery = root/'logs/wtr'/args.batch
    flight = delivery/'PCA_PREDICTIVE_s501.wtr'
    executable = root/'apps/windtrace/dist/WindTrace/WindTrace.exe'
    assert flight.is_file() and executable.is_file()
    if args.live_only:
        live_check(root, delivery, flight)
        return
    output = delivery/'replay_checks'; output.mkdir(exist_ok=False)
    environment = dict(os.environ)
    for key in ['PYTHONHOME', 'PYTHONPATH', 'VIRTUAL_ENV']:
        environment.pop(key, None)
    environment['PATH'] = os.environ['SystemRoot']+'/System32;'+os.environ['SystemRoot']
    environment['QT_QPA_PLATFORM'] = 'offscreen'
    stages = []
    for name, at in [('takeoff', 6), ('hover', 14), ('disturbance', 21), ('recovery', 32), ('hold_tail', 52)]:
        report, screenshot = output/(name+'.json'), output/(name+'.png'); started = time.monotonic()
        with (output/(name+'.log')).open('wb') as stream:
            process = subprocess.run([str(executable), str(flight), '--time', str(at), '--screenshot', str(screenshot),
                '--report', str(report), '--settings-file', str(output/(name+'.ini'))], env=environment, cwd=output,
                stdout=stream, stderr=stream, timeout=55)
        assert process.returncode == 0, name
        value = json.loads(report.read_text(encoding='utf-8'))
        assert value['loaded_flights'] == 1 and value['view3d_available'] and not value['last_error'] and not value['empty_prompt_visible'], value
        assert screenshot.stat().st_size > 20000
        stages.append({'stage': name, 'time_s': at, 'image': screenshot.relative_to(delivery).as_posix(),
                       'report': report.relative_to(delivery).as_posix(), 'elapsed_s': round(time.monotonic()-started, 3), 'passed': True})
        print('REPLAY_OK', name, at, flush=True)
    with (delivery/'replay_summary.json').open('x', encoding='utf-8') as stream:
        json.dump({'passed': True, 'batch': args.batch, 'method': 'PCA_PREDICTIVE', 'seed': 501,
                   'stages': stages, 'landing_performed': False, 'tail_policy': 'Hold altitude; no landing model.',
                   'desktop_control_used': False, 'flight_simulations_run': 0}, stream, ensure_ascii=False, indent=2)


def live_check(root, delivery, flight):
    # 用真实Qt计时和三维渲染推进两秒，不操作用户鼠标或启动新仿真。
    os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen'); os.environ.setdefault('QT_API', 'pyside6')
    sys.path.insert(0, str(root/'apps/windtrace'))
    from PySide6 import QtCore, QtWidgets
    from ui.main_window import MainWindow
    from app import configure_font
    app = QtWidgets.QApplication([]); configure_font(app)
    settings = QtCore.QSettings(str(delivery/'replay_checks/live.ini'), QtCore.QSettings.Format.IniFormat)
    window = MainWindow(settings=settings)
    try:
        window.show(); window.load([flight]); app.processEvents()
        assert window.view.plotter is not None and window.play.isEnabled()
        window.slider.setValue(round(6/55*10000)); before = window._current_time
        window.toggle_play(); loop = QtCore.QEventLoop(); QtCore.QTimer.singleShot(2000, loop.quit)
        started = time.monotonic(); loop.exec(); elapsed = time.monotonic()-started
        after = window._current_time; window.toggle_play()
        assert after > before+1 and abs((after-before)-elapsed) < .5, (before, after, elapsed)
        assert window.screenshot(delivery/'replay_checks/live_playback.png')
        result = {'passed': True, 'start_time_s': before, 'end_time_s': after, 'wall_seconds': elapsed,
                  'playing_paused_after_check': not window.playing, 'view3d_available': True,
                  'desktop_control_used': False, 'simulation_calls': 0,
                  'implementation': 'Source UI with actualQt timer; packagedEXE separately checked at five stages.'}
        with (delivery/'playback_live.json').open('x', encoding='utf-8') as stream:
            json.dump(result, stream, ensure_ascii=False, indent=2)
        print('LIVE_PLAYBACK_OK', before, after, flush=True)
    finally:
        window.close(); app.processEvents()


if __name__ == '__main__':
    main()
