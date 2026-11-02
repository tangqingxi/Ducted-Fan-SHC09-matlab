"""从一次已保存飞行导出.wtr；完整MATLAB字符串建议经MATLAB入口转换。"""
import argparse
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"apps/windtrace"))
from core.exporter import export_flight


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source",type=Path)
    parser.add_argument("output",type=Path)
    parser.add_argument("--normalized-input",type=Path,help=argparse.SUPPRESS)
    args=parser.parse_args()
    flight=export_flight(args.source,args.output,args.normalized_input)
    print(f"WTR_OK {flight.path} parameters={len(flight.parameters)} unknown={len(flight.manifest['unknown_parameter_fields'])}")


if __name__=="__main__": main()
