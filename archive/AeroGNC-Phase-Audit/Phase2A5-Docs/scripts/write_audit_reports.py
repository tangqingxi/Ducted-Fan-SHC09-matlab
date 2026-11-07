"""根据已验证的文档差异生成阶段审计报告，不回写既有阶段证据。"""
from pathlib import Path
import csv
import hashlib
import json
import subprocess

OUT=Path(__file__).resolve().parents[1]
MAIN=Path('E:/Ducted-Fan-SHC09-matlab')


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    before=json.loads((OUT/'evidence/DOCUMENT_BASELINE.json').read_text(encoding='utf-8'))
    validation=json.loads((OUT/'DOCUMENT_LINK_VALIDATION.json').read_text(encoding='utf-8'))
    publication=json.loads((OUT/'evidence/PUBLISHED_MAIN_VERIFICATION.json').read_text(encoding='utf-8'))
    with (OUT/'DOCUMENT_CHANGE_MANIFEST.csv').open(encoding='utf-8',newline='') as f:changes=list(csv.DictReader(f))
    table='\n'.join(f"| `{r['path']}` | {r['action']} | {r['before_lines']} → {r['after_lines']} | {r['before_size_bytes']} → {r['after_size_bytes']} |" for r in changes)
    total_old=sum(int(r['before_lines']) for r in changes)
    total_new=sum(int(r['after_lines']) for r in changes)
    summary=f'''# 文档整改前后对照

science_baseline_commit：`{before['science_baseline_commit']}`。

documentation_update_commit / current_main_commit：`{publication['documentation_update_commit']}`。本轮仅文档，科学基准没有随HEAD漂移。

| 文档 | 动作 | 行数 | 原始字节数 |
|---|---|---:|---:|
{table}

共10份文档，7份重写、3份新增，总计{total_old} → {total_new}行。行数减少只是结构变化的说明，不是可读性或技术准确性的独立证明。

## 首页

以前把历史分支公告、实验参数和逐日任务叠加在项目介绍前。现在先解释用途和六舵面分配问题，再介绍模块、两条运行链、反馈模式、一个2秒短例、实际目录、研究证据和按角色阅读路线。首页没有搬入完整实验数值表或重复研究公式。

## Agent与当前交接

AGENTS从770行压缩到76行，维护稳定契约：信息隔离、冻结来源、权限、路径、中文注释、验证与Git。删除旧“不合并/不push/旧分支待审”等临时指令；没有删去科学证据保护要求，也不再建议更新旧锁来追认新实现。

HANDOFF从498行压缩到49行，只保留main、三种提交身份、已完成阶段、Phase2A.5和Phase2B审批。文档提交/当前HEAD使用git现场查询，避免在包含自身的提交中硬编码自引用SHA；本审计报告另记录实际新提交。

## 分层阅读

docs/README按首次使用、研究、贡献与Agent导航；repository_map只说明实际目录；architecture解释两条控制链与信息/时钟边界。新增getting_started、research_workflows、results_and_evidence分别维护运行、任务规模和证据语义，不再让根README承担所有角色。

WORKSPACE_MIGRATION转为迁移历史说明，明确旧controller worktree已清理及旧迁移归档不再存在。不能继续把历史路径当作可用备份。旧正文通过339d7b1a固定提交、17份原报告追溯，不复制或改写历史结论。

## 保持原样

数值源码、源锁/协议、MAT/WTR、输入/指标、在用WindTrace、17份codex-repo报告和Phase1/Phase2A交付均未修改。未执行仿真、参数扫描、MATLAB测试套件、ECL/WindTrace构建、原始数据备份或Results迁移。
'''
    (OUT/'BEFORE_AFTER_SUMMARY.md').write_text(summary,encoding='utf-8',newline='\n')
    report=f'''# Phase2A.5项目文档体系重构报告

日期：2026-11-04（Asia/Shanghai）。本阶段重写当前文档入口，暂停Phase2B；不是源码或Results重构。

## 交付状态与Git身份

- science_baseline_commit：**`{before['science_baseline_commit']}`**。
- documentation_update_commit：**`{publication['documentation_update_commit']}`**。
- current_main_commit与origin/main/远端main均为上述文档提交，仅一个E盘worktree。收尾曾出现任务外未跟踪目录`.tmp_skill_review/`，未创建/暂存/清理并停止主库覆盖操作；后续只读复查时该目录已不存在，主工作区干净。现场记录见[evidence/UNRELATED_WORKTREE_STATE.json](evidence/UNRELATED_WORKTREE_STATE.json)。
- 主提交：`docs: reorganize project documentation and agent guidance`，仅10份Markdown，没有新开发分支、强推或历史重写。
- 独立审计仓库开工提交：`{before['audit_baseline_commit']}`；本目录随后独立提交/推送，实际审计提交SHA以Git记录和交付回复为准，避免自引用。

[新版GitHub README](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/blob/{publication['documentation_update_commit']}/README.md) · [主仓库文档提交](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/commit/{publication['documentation_update_commit']})。

## 本次文档结构

首页按用途、过驱动分配问题、五算法、反馈数据流、两条运行链、已实现功能、快速开始、真实目录与研究证据组织，最后提供读者角色导航。当前仍是SHC09平台；AeroGNC-Sim多机型、统一Results和WindTrace拆分均明确为规划，未声称已实现。

AGENTS维护稳定开发约束，HANDOFF维护当前main/阶段/待办，docs指南承担运行、架构、研究和证据的详细解释；旧实验参数和历史结论留原协议/报告。README不再采用顶部累积公告方式。具体前后对照见[BEFORE_AFTER_SUMMARY.md](BEFORE_AFTER_SUMMARY.md)。

文件清单与完整本地字节SHA、旧Git blob正文SHA、新blob OID及两种提交身份见[DOCUMENT_CHANGE_MANIFEST.csv](DOCUMENT_CHANGE_MANIFEST.csv)。这里区分工作树原字节与Git正文，不用换行归一化改写冻结科学身份。

## 技术核对的依据

静态读取main、main_comparison、shc09_run、platform_run、ca_setup、hover_app、shc09_airframe、ca_config/validate_config；核实短例2秒、默认不保存、Optimization Toolbox许可和实际输出路径。

读取registry、DA_NS/DCA实现及方法适配；五正式方法和EXAMPLE_PINV示例分开。读取ppid_control_step、ppid_simulate/研究驱动、GNSS版本化loader、CaPx4Ecl与构建脚本，区分平台与四环控制器、PWM/控制时钟、理想参考、lite和外部ECL桥接。平台ECL模式不自动等于GNSS v2。

具体来源路径/当前SHA及可机读检查见[evidence/TECHNICAL_SOURCE_CHECKS.json](evidence/TECHNICAL_SOURCE_CHECKS.json)。实验状态依据既有F8/PPID交付、55秒两批、Round 1–7、GNSS v2报告及Phase2A冻结/保护计划；没有新增算法优越性、实机标定或完整EKF2/SITL声明。

GNSS真实恢复限制继续在[Issue #1](https://github.com/tangqingxi/Ducted-Fan-SHC09-matlab/issues/1)暂缓，非当前文档/结构治理阻塞。不调参、不改判据，不要求它先通过才推进后续文档或Results治理。

## 验证结果与保护证据

| 检查 | 本轮结果 |
|---|---|
| 原文档检查工具 | 89份Markdown、563个本地链接、0断链 |
| 新文档锚点/旧页面反向链接 | 无缺失锚点或新引入的断链 |
| 主提交范围 | 恰为10份授权Markdown；没有数值、锁、协议或其他文件差异 |
| 非授权跟踪文件 | 1736项完整字节SHA不变，包含17份历史Agent报告 |
| Phase2A保护工件 | 排除本轮授权文档后11137项大小/mtime不变，覆盖正式MAT/WTR、来源/输入、当前完整Viewer等；未重复读取全部大数据 |
| 旧审计交付 | Phase1/Phase2A/Git-Convergence共95项SHA不变 |
| GitHub交付字节 | 10份已发布文档均HTTP200，raw正文、本地文件、Git正文、GitHub tree OID/大小一致 |
| GitHub服务器Markdown | 返回article、8个主/次标题、4个表格，识别Mermaid enrichment容器且原图代码保留，无解析错误消息 |
| Mermaid本地验证 | draw.io成功转换并导出，已查看8节点闭环图像；[预览PNG](diagrams/system-flow.drawio.png)嵌入可编辑图数据 |

完整检查见[DOCUMENT_LINK_VALIDATION.json](DOCUMENT_LINK_VALIDATION.json)及[evidence/PUBLISHED_MAIN_VERIFICATION.json](evidence/PUBLISHED_MAIN_VERIFICATION.json)。GitHub服务器HTML响应另存[evidence/GITHUB_README_RENDERED.html](evidence/GITHUB_README_RENDERED.html)。

## 剩余限制，不能冒充已通过

浏览器控制工具在内置浏览器与已连接Edge读取页面时连续超时，**未直接截图确认GitHub客户端动态SVG或做跨屏幕视觉测试**。本轮实际通过的是GitHub原始正文/服务器Markdown及Mermaid源码一致性，以及draw.io解析和图像查看；不将其表述为已完成客户端截图验收。

主文档已推送后曾出现的`.tmp_skill_review/`属于任务外未跟踪内容，未加入本提交，也未为制造干净状态而删除、忽略或stash。它在后续只读复查时已不存在，未调查或改写其他任务的操作。文档本身与已发布Git字节一致，受保护跟踪文件及数据未变；先前出现和最终工作树状态分别记录。

示例命令只按源码静态核对，未在本轮MATLAB实际运行。run_project_tests、run_platform_tests、test_platform_baseline等会推进对象或写结果，因此跳过；未重建ECL或WindTrace。旧兼容/逐位基线、lite偏置门禁及真实恢复失败的历史记录保留，没有宣称全套测试通过。

主库保护工件采用大小/mtime复核，非授权跟踪文件另做完整SHA；不声称本轮对全部本机23.6 GB重新计算内容hash。没有原始数据复制、清理或迁移。

## 下一步与停止点

本目录与主文档均提交/推送后停止，不进入Phase2B。后续仍需批准独立备份设备/路径、保护范围、恢复验证、真实登记和逐文件Results迁移权限。原change-B后续研究另定协议/来源/运行预算；不重建旧远端分支或追加正式批。

drawio技能用于本地Mermaid转换/预览；首页仍按用户要求保留GitHub原生Mermaid。computer-use技能用于只读浏览器尝试，工具超时已记录。规范性参考：[GitHub图表文档](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams)。
'''
    (OUT/'DOCUMENTATION_REFACTOR_REPORT.md').write_text(report,encoding='utf-8',newline='\n')
    # 仅统一本阶段新建文本的LF，不改旧审计或主仓库文件。
    for p in OUT.rglob('*'):
        if p.is_file() and p.suffix.lower()!='.png':
            b=p.read_bytes()
            if b'\r\n' in b:p.write_bytes(b.replace(b'\r\n',b'\n'))
    print(json.dumps(dict(main_commit=publication['documentation_update_commit'],documents=10,before_lines=total_old,after_lines=total_new,report=str(OUT/'DOCUMENTATION_REFACTOR_REPORT.md')),ensure_ascii=True))


if __name__=='__main__':main()
