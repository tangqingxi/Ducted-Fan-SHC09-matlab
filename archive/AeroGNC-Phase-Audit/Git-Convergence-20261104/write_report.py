"""根据已完成核验记录生成仓库外收尾报告与交付哈希。"""
from pathlib import Path
import csv
import hashlib
import json

OUT=Path(__file__).resolve().parent


def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda:f.read(1048576),b''):
            h.update(data)
    return h.hexdigest()


def main():
    v=json.loads((OUT/'VERIFICATION.json').read_text(encoding='utf-8'))
    before=json.loads((OUT/'before.json').read_text(encoding='utf-8'))
    after=json.loads((OUT/('final.json' if (OUT/'final.json').exists() else 'after.json')).read_text(encoding='utf-8'))
    deletion=json.loads((OUT/'deletion_verified.json').read_text(encoding='utf-8'))
    if not v['passed']:
        raise RuntimeError('完整性核验尚未通过，不生成完成报告')
    tags='\n'.join(f'| `{name}` | `{head}` |' for name,head in sorted(v['remote_tags'].items()))
    deleted='、'.join(f'`{name}`' for name in deletion['deleted_branches'])
    controller_lines=after['controller']['status'].splitlines()
    modified=sum(not x.startswith('??') for x in controller_lines)
    untracked=sum(x.startswith('??') for x in controller_lines)
    groups=[]
    for name,test in [('results全部文件',lambda p:p.startswith('results/')),('日志全部文件',lambda p:p.startswith('logs/')),('全部MAT（含环境测试数据）',lambda p:p.lower().endswith('.mat')),('WTR',lambda p:p.lower().endswith('.wtr')),('WindTrace.exe',lambda p:Path(p).name=='WindTrace.exe')]:
        rows=[r for r in before['primary']['files'] if test(r['path'])]
        groups.append(dict(group=name,files=len(rows),bytes=sum(r['size_bytes'] for r in rows),all_sha256_checked=all('sha256' in r for r in rows)))
    with (OUT/'DATA_PROTECTION_SUMMARY.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(groups[0]))
        writer.writeheader()
        writer.writerows(groups)
    gt='\n'.join(f"| {g['group']} | {g['files']:,} | {g['bytes']:,} | {g['all_sha256_checked']} |" for g in groups)
    text=f'''# Git分支收敛与主线切换收尾

日期：2026-11-04（Asia/Shanghai）。仓库：`E:/Ducted-Fan-SHC09-matlab`。GitHub仓库名保持`tangqingxi/Ducted-Fan-SHC09-matlab`。

本次仅执行用户授权的Tag归档、8个指定远端分支删除、本地main切换及快进、fetch/prune和完整性核验。未重复合并、未force push、未新建提交、未重写历史、未重构文件、未更名仓库、未运行仿真。

## 最终远端与主线

- GitHub默认分支仍为`main`；远端仅有一个开发分支`main`。
- 本地`main`、`origin/main`及远端`refs/heads/main`均为`339d7b1a997de6ba350cef3207d8a5b7db3d838d`。
- E盘工作树当前为`main`，Git工作区干净。本地main原为9918d9d，通过`git switch main`、`git fetch origin --prune`、`git merge --ff-only origin/main`快进30个既有提交，没有创建合并提交。
- 成功删除远端分支8/8：{deleted}。未删除main。

## viz-replay归档及全部远端Tags

删除前确认viz-replay有21个不属于main的提交，归档Tag为`archive/viz-replay-20261104`，指向原远端HEAD `{v['archive_expected_head']}`。先推送并使用`git ls-remote --tags`核验精确SHA，再执行删除；删除后又从远端核验可访问。

其余待删除远端分支均以`git merge-base --is-ancestor`确认其原HEAD包含于目标main。既有远端Tags指向全部保持；当前远端共{v['remote_tag_count']}个Tag：

| Tag | 远端Tag对象/提交SHA |
|---|---|
{tags}

本次新增的是轻量归档Tag。表中已有annotated tag如存在，其Tag对象SHA与最终提交的peeled SHA可能不同；完整原始引用含peeled行保存在before/after.json中，未更改既有Tag。

## 本地分支及所有worktree

18个本地分支均保留，除main快进外其余分支HEAD未变。逐分支独有提交检查见[LOCAL_BRANCH_REVIEW.csv](LOCAL_BRANCH_REVIEW.csv)。viz-replay本地分支仍有21个独有提交，并另有远端归档Tag保护；未为了只保留一个远端开发分支而强删本地工作。

另一个worktree：`C:/Users/32450/.codex/worktrees/controller-ppid-p-indi/Ducted-Fan-SHC09-matlab`，分支`controller-ppid-p-indi`，HEAD `7c5c9ab91fdb310c33d5bf08209e0302e540008f`。该分支已提交历史没有main之外的独有提交，但工作树有{modified}个已跟踪修改文件和{untracked}个未跟踪文件；二者不混为“已经可删除”。其1287个文件的元数据前后无变化，1267项内容SHA一致，Git修改清单逐项不变。未执行checkout/restore/reset/stash/clean、工作树删除或强制分支删除。

## 历史与原始数据完整性

GNSS v2、ECL诊断、Round 7及change-B历史仍由main可达；main最终HEAD与原debug-ecl-position完全相同。关键GNSS入口/协议及诊断报告存在，源工作树有SHA记录的文件前后内容差异0。

科学状态未改写：1000 s新模型修正与单条55秒数值回归完成，但真实恢复仍未通过原判据；分支收敛不代表性能验收通过。

主工作树96,300个文件路径集合及字节大小一致；74,939个文件、21,733,869,521字节做前后完整SHA256。另一worktree另校验690,857,308字节。分组如下，组之间有包含关系，不可求和：

| 保护分组 | 文件数 | 字节数 | 每项均完整SHA核对 |
|---|---:|---:|---|
{gt}

Results、日志、MAT、WTR及EXE最终无内容或元数据差异。分支切换过程中，Git依现有换行规则写出75份文本，造成临时字节差异，并使994个受跟踪文件mtime更新；全部文本已按执行前SHA精确重建（含4份混合换行文本），994个mtime也已恢复。恢复前逐项核查没有外部新修改；恢复后逐项重读并验证原SHA。没有改源码逻辑、配置、指标、Git对象或提交内容。

最终全树元数据再核验无差异，内容SHA差异0。controller工作树全过程无内容或元数据变化。元数据清单覆盖全部工作树文件，未跟随链接到无关磁盘，未把.git对象库和本地环境的所有文件声明为已做内容hash。Results全部文件已实际进行完整SHA比对。

原字节恢复后，逐项确认75份文件经Git清洁过滤的blob均与索引相同，随后仅刷新索引的工作文件统计缓存；刷新前后所有索引blob/模式条目完全一致，暂存差异为空，工作区干净。没有以隐藏修改或改变Git配置的方式消除状态。

## 核验证据

- [VERIFICATION.json](VERIFICATION.json)：最终核验`passed=true`、数据差异、远端引用、既有Tags及本地分支保护结果。
- [operations.jsonl](operations.jsonl)：归档、删除、switch/fetch/ff-only等命令及完整退出码/输出。
- [before.json](before.json)、[after.json](after.json)、[final.json](final.json)：执行前、checkout后完整SHA复核中间状态及恢复后的最终状态；包含所有worktree、远端分支、默认分支、全部Tags。
- [CHECKOUT_BYTE_RESTORATION_PLAN.json](CHECKOUT_BYTE_RESTORATION_PLAN.json)：75份文本的执行前、checkout后及精确恢复SHA。较大原始数据沿用after.json的完整复核；恢复操作仅针对已确认的受跟踪文件，之后重读这些文件并核对全树元数据。
- [INDEX_REFRESH_VERIFIED.json](INDEX_REFRESH_VERIFIED.json)：原字节恢复后的75项blob身份及索引前后完全一致证明，暂存差异为空。
- [archive_verified.json](archive_verified.json)、[deletion_verified.json](deletion_verified.json)：删除前归档门禁和8个删除结果。
- [DATA_PROTECTION_SUMMARY.csv](DATA_PROTECTION_SUMMARY.csv)、[LOCAL_BRANCH_REVIEW.csv](LOCAL_BRANCH_REVIEW.csv)：分组保护及本地分支审查。

任务完成后停止。本次证据保存在仓库外，未修改上一轮Phase1交付。
'''
    (OUT/'REPORT.md').write_text(text,encoding='utf-8')
    entries=[dict(path=p.name,bytes=p.stat().st_size,sha256=sha(p)) for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='DELIVERY_MANIFEST.json']
    (OUT/'DELIVERY_MANIFEST.json').write_text(json.dumps(dict(files=entries),ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(report=str(OUT/'REPORT.md'),passed=v['passed'],remote_tag_count=v['remote_tag_count'],controller_modified_files=modified,controller_untracked_files=untracked,metadata_only_changes=len(v['primary']['metadata_changed_files'])),ensure_ascii=True))


if __name__=='__main__':
    main()
