param(
    [Parameter(Mandatory=$true)][string]$PythonExecutable,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
# 仅在全新目录构建，不隐式安装、替换旧版或更改桌面快捷方式。
$ErrorActionPreference = 'Stop'
$ApplicationRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputRoot) { throw "构建目录已经存在：$OutputRoot" }
if (-not (Test-Path -LiteralPath $PythonExecutable)) { throw 'Python解释器不存在。' }
New-Item -ItemType Directory -Path $OutputRoot | Out-Null
$TemporaryRoot = Join-Path $OutputRoot 'temp'
New-Item -ItemType Directory -Path $TemporaryRoot | Out-Null
$PreviousTemp = $env:TEMP
$PreviousTmp = $env:TMP
$PreviousPath = $env:PATH
try {
    $env:TEMP = $TemporaryRoot
    $env:TMP = $TemporaryRoot
    # 只向构建器提供Python与Windows路径，避免收集Poppler等工具的同名不兼容DLL。
    $BasePython = (& $PythonExecutable -c "import sys; print(sys.base_prefix)").Trim()
    if ($LASTEXITCODE -ne 0) { throw '读取Python基础环境失败。' }
    $env:PATH = @((Split-Path -Parent $PythonExecutable),$BasePython,(Join-Path $BasePython 'DLLs'),(Join-Path $env:SystemRoot 'System32'),$env:SystemRoot) -join ';'
    & $PythonExecutable -m PyInstaller --clean --distpath (Join-Path $OutputRoot 'dist') --workpath (Join-Path $OutputRoot 'build') (Join-Path $ApplicationRoot 'WindTrace.spec') 2>&1 | Tee-Object -FilePath (Join-Path $OutputRoot 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'PyInstaller构建失败，保留构建日志。' }
    $Program = Join-Path $OutputRoot 'dist\WindTrace\WindTrace.exe'
    if (-not (Test-Path -LiteralPath $Program)) { throw '未生成可执行文件。' }
    Write-Output "已构建：$Program"
} finally {
    $env:TEMP = $PreviousTemp
    $env:TMP = $PreviousTmp
    $env:PATH = $PreviousPath
}
