"""显示单种子开发压力试验中的真实lambda、beta和回退，不作确认性箱线图。"""
import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

import plot_figure8_lite as base


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("screen_dir",type=Path);args=parser.parse_args()
    folder=args.screen_dir.resolve();summary=base.read_csv(folder/"development_priority_summary.csv")
    trace=base.read_csv(folder/"development_priority_trace.csv");status=base.read_csv(folder/"status.csv")
    assert len(status)==9 and all(r["status"] in ("completed","failed") for r in status)
    ids=list(dict.fromkeys(r["scenario_id"] for r in summary));assert len(ids)==3
    target=folder/"development_priority_lambda_beta.png";assert not target.exists(),"不覆盖已生成的开发图"
    plt.rcParams.update({"font.family":"sans-serif","font.sans-serif":["Microsoft YaHei","SimHei","DejaVu Sans"],"axes.unicode_minus":False,"pdf.fonttype":42})
    fig,axes=plt.subplots(3,2,figsize=(16,11),layout="constrained")
    for row,id in enumerate(ids):
        for column,field in enumerate(["lambda","beta"]):
            ax=axes[row,column]
            for method in ["PCA_STATIC","PCA_PREDICTIVE"]:
                selected=[r for r in trace if r["scenario_id"]==id and r["method"]==method]
                t=np.array([float(r["time_s"]) for r in selected]);value=np.array([float(r[field]) for r in selected]);mode=np.array([int(r["mode"]) for r in selected])
                color=base.COLORS[base.METHODS.index(method)];label=base.LABELS[base.METHODS.index(method)]
                ax.step(t,value,where="post",lw=1,color=color,label=label)
                active=(mode==2)&(t>=6)&(t<=50)
                if active.any():
                    ax.scatter(t[active],np.full(active.sum(),-0.025),s=6,color=color,marker="|",label=label+"模式2标记")
            rows=[r for r in summary if r["scenario_id"]==id]
            note="；".join(("静态" if r["method"]=="PCA_STATIC" else "预测")+f"{'正常缩放' if field=='lambda' else '高优先级回退'}{float(r['normal_scaled_duration_s' if field=='lambda' else 'high_priority_fallback_duration_s']):.3g}s" for r in rows)
            ax.set(title=f"{id} · {note}",xlim=(6,50),ylim=(-0.05,1.05),xlabel="时间 / s",ylabel="λ（mode0）" if field=="lambda" else "β（mode1）")
            ax.grid(alpha=0.2);ax.spines[["top","right"]].set_visible(False)
    axes[0,0].legend(frameon=False,fontsize=9);axes[-1,-1].legend(frameon=False,fontsize=8)
    failed=sum(r["status"]=="failed" for r in status)
    fig.suptitle(f"F8-P-v2 · 开发压力试验 seed9002（不是独立确认；运行失败{failed}/9保留在status.csv）\n已完成日志按800Hz统计；缺失系数保持NaN，模式2仅用底部记号；缩放不自动等于优先级证据",fontsize=14)
    fig.savefig(target,dpi=180,facecolor="white");fig.savefig(target.with_suffix(".pdf"),facecolor="white");plt.close(fig)
    print(json.dumps(dict(development_cases=3,independent_confirmation=False,figure=str(target)),ensure_ascii=False))


if __name__=="__main__":
    main()
