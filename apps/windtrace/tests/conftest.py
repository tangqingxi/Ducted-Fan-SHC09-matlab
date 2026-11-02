"""测试仅构造短日志，不调用飞行动力学。"""
import os
from pathlib import Path
import sys

os.environ.setdefault("QT_QPA_PLATFORM","offscreen")
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
