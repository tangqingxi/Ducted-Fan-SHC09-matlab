"""沿用WindTrace原版视觉组件与设计令牌；来源见IMPORT_PROVENANCE.json。"""





from __future__ import annotations

from pathlib import Path

from PySide6 import QtGui

QSS_PATH = Path(__file__).with_name("theme.qss")


COLORS = {
    "bg": "#F5F6F8",
    "surface": "#FFFFFF",
    "border": "#E5E7EB",
    "muted": "#9CA3AF",
    "text": "#111827",
    "secondary": "#4B5563",
    "group_title": "#6B7280",
    "accent": "#2563EB",
    "accent_hover": "#2563EB",
    "danger": "#DC2626",
    "grid_minor": "#DDE1E6",
    "grid_major": "#CFD5DC",
    "reference": "#C7CBD1",
    "segment_bg": "#F3F4F6",
    "segment_border": "#D1D5DB",
    "overlay": "rgba(255, 255, 255, 0.85)",
}

METHOD_COLORS = {
    "DA_NS": "#1F77B4",
    "WLS": "#2CA02C",
    "DCA": "#FF7F0E",
    "PCA_STATIC": "#9467BD",
    "PCA_PREDICTIVE": "#D62728",
}

MODEL_COLORS = {
    "body": "#2B2D31",
    "duct": "#FFFFFF",
    "rotor": "#1A1B1D",
    "leg": "#1A1B1D",
    "vane": "#232529",
}

GEOMETRY_COLORS = {
    "duct": "#4B5563",
    "fan": "#9CA3AF",
    "vane": "#9CA3AF",
    "body_face": "#FFFFFF",
    "body_edge": "#9CA3AF",
}

SPACING = {"xxs": 4, "xs": 8, "sm": 12, "md": 16, "lg": 24, "drawer": 220}
RADIUS = {"control": 6, "card": 8, "dot": 4, "slider": 2, "handle": 6, "capsule": 999}
FONTS = {"app": 12, "curve": 10.5, "section": 9.5, "body": 9, "tiny": 8.5, "small": 8}
HEIGHTS = {"top": 52, "bottom": 48, "status": 24, "control": 32, "rail": 36, "curve_min": 360, "curve_max": 560}
FONT_FAMILY = "Microsoft YaHei UI"
FONT_FILE = r"C:\Windows\Fonts\msyh.ttc"
MONO_FONT = "Consolas"


VANE_BLUE_RGB = (40, 90, 230)
SAT_RED_RGB = (220, 30, 30)


def color(name: str) -> str:
    return COLORS[name]


def method_color(method: str) -> str:
    return METHOD_COLORS.get(str(method), COLORS["muted"])


def _replacements() -> dict[str, str]:
    out = {
        "{{BG}}": COLORS["bg"],
        "{{SURFACE}}": COLORS["surface"],
        "{{BORDER}}": COLORS["border"],
        "{{TEXT}}": COLORS["text"],
        "{{SECONDARY}}": COLORS["secondary"],
        "{{MUTED}}": COLORS["muted"],
        "{{GROUP_TITLE}}": COLORS["group_title"],
        "{{ACCENT}}": COLORS["accent"],
        "{{ACCENT_HOVER}}": COLORS["accent_hover"],
        "{{DANGER}}": COLORS["danger"],
        "{{GRID_MINOR}}": COLORS["grid_minor"],
        "{{GRID_MAJOR}}": COLORS["grid_major"],
        "{{REFERENCE}}": COLORS["reference"],
        "{{SEGMENT_BG}}": COLORS["segment_bg"],
        "{{SEGMENT_BORDER}}": COLORS["segment_border"],
        "{{OVERLAY}}": COLORS["overlay"],
        "{{SP4}}": f"{SPACING['xxs']}px",
        "{{SP8}}": f"{SPACING['xs']}px",
        "{{SP12}}": f"{SPACING['sm']}px",
        "{{SP16}}": f"{SPACING['md']}px",
        "{{SP24}}": f"{SPACING['lg']}px",
        "{{R6}}": f"{RADIUS['control']}px",
        "{{R8}}": f"{RADIUS['card']}px",
        "{{R2}}": f"{RADIUS['slider']}px",
        "{{R7}}": f"{RADIUS['handle']}px",
        "{{R6H}}": f"{RADIUS['handle']}px",
        "{{R999}}": f"{RADIUS['capsule']}px",
        "{{F8}}": f"{FONTS['small']}pt",
        "{{F8_5}}": f"{FONTS['tiny']}pt",
        "{{F9}}": f"{FONTS['body']}pt",
        "{{F9_5}}": f"{FONTS['section']}pt",
        "{{F10_5}}": f"{FONTS['curve']}pt",
        "{{F12}}": f"{FONTS['app']}pt",
        "{{MONO}}": MONO_FONT,
        "{{CTRL_H}}": f"{HEIGHTS['control']}px",
        "{{TOPBAR_H}}": f"{HEIGHTS['top']}px",
        "{{BOTTOM_H}}": f"{HEIGHTS['bottom']}px",
        "{{STATUS_H}}": f"{HEIGHTS['status']}px",
    }
    return out


def stylesheet() -> str:
    text = QSS_PATH.read_text(encoding="utf-8")
    for key, value in _replacements().items():
        text = text.replace(key, value)
    return text


def apply_theme(app) -> None:
    app.setStyle("Fusion")
    font = QtGui.QFont(FONT_FAMILY)
    font.setPointSize(FONTS["body"])
    app.setFont(font)
    palette = app.palette()
    palette.setColor(QtGui.QPalette.ColorRole.Highlight, QtGui.QColor(COLORS["accent"]))
    palette.setColor(QtGui.QPalette.ColorRole.HighlightedText, QtGui.QColor(COLORS["surface"]))
    app.setPalette(palette)
    app.setStyleSheet(stylesheet())


def font(size_key: str, bold: bool = False) -> QtGui.QFont:
    f = QtGui.QFont(FONT_FAMILY)
    f.setPointSizeF(float(FONTS[size_key]))
    f.setBold(bold)
    return f
