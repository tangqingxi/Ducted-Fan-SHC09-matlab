"""仅计算已知数字滤波链的名义相位，不改仿真、不参与候选选型。"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np


def lowpass(cutoff, sample_hz, frequency):
    # 与ca_biquad的普通Tustin二阶低通系数一致，不作截止频率预畸变。
    w, k = 2*np.pi*cutoff, 2*sample_hz
    damping = 1/np.sqrt(2)
    b = w*w*np.array([1, 2, 1])
    a = np.array([k*k+2*damping*w*k+w*w, -2*k*k+2*w*w, k*k-2*damping*w*k+w*w])
    powers = np.exp(-1j*2*np.pi*frequency/sample_hz*np.arange(3))
    return (b @ powers)/(a @ powers)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    assert not output.exists()
    output.mkdir()
    rows = []
    for h1, h2 in [(8, 8), (10, 10), (12, 12), (15, 15), (12, 8), (8, 12)]:
        for frequency in [.5, .75, 3, 5]:
            omega = 2*np.pi*frequency/400
            z = np.exp(-1j*omega)
            derivative_relative = (1-z)/(1j*omega)
            alpha = lowpass(h1, 400, frequency)*z*derivative_relative
            delta = lowpass(h2, 400, frequency)*z
            imu = lowpass(100, 800, frequency)*np.exp(-1j*2*np.pi*frequency*.0025)
            relative = alpha/delta
            with_imu = relative*imu
            rows.append({"h1_hz": h1, "h2_hz": h2, "frequency_hz": frequency,
                         "alpha_phase_deg": float(np.angle(alpha, deg=True)),
                         "delta_phase_deg": float(np.angle(delta, deg=True)),
                         "relative_alpha_minus_delta_phase_deg": float(np.angle(relative, deg=True)),
                         "relative_alpha_lag_ms": float(-np.angle(relative)/(2*np.pi*frequency)*1000),
                         "relative_including_known_imu_phase_deg": float(np.angle(with_imu, deg=True)),
                         "relative_including_known_imu_lag_ms": float(-np.angle(with_imu)/(2*np.pi*frequency)*1000),
                         "alpha_relative_magnitude": float(abs(alpha)), "delta_relative_magnitude": float(abs(delta))})
    path = output / "nominal_phase.csv"
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    lines = ["# H1/H2名义时间对齐诊断", "", "本诊断不参与选型，不改变控制器，也没有实施相位超前。", "",
             "400Hz角加速度链包含H1、一拍延迟、后向差分相对理想导数的半拍相位；舵角链包含H2和一拍延迟。两链共同的传感器缓冲延迟在相对相位中抵消。另列100Hz IMU低通（800Hz采样）及2.5ms传输对角速度路径的已知附加相位。", "",
             "未计入ECL内部处理、非线性运动耦合和舵角估计的模型误差，因此这些数值不是实测完整链路延迟，也不能据此宣称完全同步。正的相对延迟表示角加速度路径更滞后。", "",
             "|H1/H2 Hz|0.5Hz数字差分与滤波相对延迟 ms|加已知IMU链后的相对延迟 ms|", "|---|---:|---:|"]
    for row in rows:
        if row["frequency_hz"] == .5:
            lines.append(f"|{row['h1_hz']}/{row['h2_hz']}|{row['relative_alpha_lag_ms']:.6g}|{row['relative_including_known_imu_lag_ms']:.6g}|")
    lines += ["", "同截止频率不能消除差分的半拍相位和仅存在于角速度侧的测量延迟；不同截止频率可以补偿相对相位，但也改变幅值和噪声。", "",
              "在理想化Bδ=α−d、d=J^-1*M_dist且没有其他项时，r=(I−Gδ)d+(Gδ−Gα)α。第一项是公共补偿对外扰的滞后，第二项才是两链不对齐项。因此滚转残差降低不能独自证明时间已经完全对齐。真实试验还含非线性配平、噪声、舵效和舵角估计误差，不能把这一简化分解当作本批精确力矩分解。", ""]
    (output / "phase_alignment_note.md").write_text("\n".join(lines), encoding="utf-8")
    with Path(__file__).open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    (output / "diagnostic_sources.json").write_text(json.dumps({"tool": str(Path(__file__).resolve()), "sha256": digest,
        "selection_input": False, "flight_simulations_run": 0}, indent=2), encoding="utf-8")
    print(json.dumps([r for r in rows if r["frequency_hz"] == .5]))


if __name__ == "__main__":
    main()
