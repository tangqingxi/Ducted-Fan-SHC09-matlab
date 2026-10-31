"""检查仓库Markdown本地链接与图片，不访问网络或仓库外路径。"""
import argparse
import os
import re
from pathlib import Path
from urllib.parse import unquote


def mask_code(text):
    # 遮盖代码但保持字符位置和换行，确保报错行号对应原文。
    lines=text.splitlines(keepends=True);fence=None;masked=[]
    for line in lines:
        marker=re.match(r"^ {0,3}(`{3,}|~{3,})",line)
        if fence:
            masked.append(re.sub(r"[^\n]"," ",line))
            if marker and marker[1][0]==fence[0] and len(marker[1])>=len(fence):fence=None
        elif marker:
            fence=marker[1];masked.append(re.sub(r"[^\n]"," ",line))
        else:masked.append(line)
    value="".join(masked)
    return re.sub(r"(`+)([^\n]*?)\1",lambda m:" "*len(m[0]),value)


def destinations(text):
    # 同时支持图片、点号文件名、尖括号空格路径及平衡圆括号。
    masked=mask_code(text)
    for m in re.finditer(r"!?\[[^\]\n]*\]\s*\(",masked):
        i=m.end()
        while i<len(masked) and masked[i].isspace():i+=1
        if i==len(masked):continue
        if masked[i]=='<':
            end=masked.find('>',i+1)
            if end>=0:yield i+1,end,text[i+1:end],text.count('\n',0,m.start())+1
        else:
            start=i;depth=0
            while i<len(masked):
                char=masked[i]
                if char=='\\' and i+1<len(masked):i+=2;continue
                if char=='(':depth+=1
                elif char==')':
                    if depth==0:break
                    depth-=1
                elif char.isspace():break
                i+=1
            if i>start:yield start,i,text[start:i],text.count('\n',0,m.start())+1
    for m in re.finditer(r"(?m)^ {0,3}\[[^\]\n]+\]:[ \t]*(<[^>\n]+>|[^ \t\n]+)",masked):
        start,end=m.span(1)
        if masked[start]=='<':start+=1;end-=1
        yield start,end,text[start:end],text.count('\n',0,m.start())+1


def local_target(root,source,value):
    value=re.sub(r"\\([\\()\[\] <>])",r"\1",value)
    if not value or value.startswith(('#','//')):return None
    windows_absolute=bool(re.match(r"^[A-Za-z]:[\\/]",value))
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:",value) and not windows_absolute:return None
    value=unquote(value.split('#',1)[0].split('?',1)[0])
    if not value:return None
    if value.startswith('/') and not windows_absolute:target=root/value.lstrip('/')
    else:target=source.parent/value
    # 先做纯文本规范化；仓库外目标不探测文件系统。
    return Path(os.path.abspath(target))


def check(root):
    root=root.resolve();sources=[root/name for name in ['README.md','HANDOFF.md','CHANGELOG.md','THIRD_PARTY_NOTICES.md','archive/README.md','archive/logs/README.md'] if (root/name).is_file()]
    for folder in ['docs','examples']:
        if (root/folder).is_dir():sources.extend(sorted((root/folder).rglob('*.md')))
    errors=[];links=0
    for source in sources:
        text=source.read_text(encoding='utf-8-sig');masked=mask_code(text)
        definitions={re.sub(r"\s+"," ",m[1]).strip().casefold() for m in re.finditer(r"(?m)^ {0,3}\[([^\]\n]+)\]:",masked)}
        for start,end,value,line in destinations(text):
            target=local_target(root,source,value)
            if target is None:continue
            links+=1
            if not target.is_relative_to(root):errors.append((source,line,value,'仓库外路径，未访问'))
            elif not target.exists():errors.append((source,line,value,'目标不存在'))
        for m in re.finditer(r"!?\[([^\]\n]+)\]\[([^\]\n]*)\]",masked):
            label=re.sub(r"\s+"," ",m[2] or m[1]).strip().casefold()
            if label not in definitions:errors.append((source,text.count('\n',0,m.start())+1,label,'引用式链接未定义'))
    for source,line,value,reason in errors:print(f'{source.relative_to(root).as_posix()}:{line}: {reason}: {value}')
    print(f'检查Markdown {len(sources)}份，本地链接 {links}个，断链 {len(errors)}处。')
    return len(errors)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);args=parser.parse_args()
    raise SystemExit(1 if check(args.root) else 0)
