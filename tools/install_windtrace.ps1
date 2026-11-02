param(
    [Parameter(Mandatory=$true)][string]$PackageDirectory,
    [Parameter(Mandatory=$true)][string]$InstallationDirectory,
    [Parameter(Mandatory=$true)][string]$BackupSuffix,
    [Parameter(Mandatory=$true)][string]$ReportFile
)
# 验证完整新包后备份替换旧程序，不删除旧版，不触碰研究数据。
$ErrorActionPreference='Stop'
if ($BackupSuffix -notmatch '^[A-Za-z0-9_-]+$') { throw '备份后缀不合法。' }
$PackageRoot=(Resolve-Path -LiteralPath $PackageDirectory).Path
$InstallRoot=[IO.Path]::GetFullPath($InstallationDirectory).TrimEnd('\')
$ParentRoot=(Resolve-Path -LiteralPath (Split-Path -Parent $InstallRoot)).Path
if ((Split-Path -Leaf $InstallRoot) -ne 'WindTrace') { throw '安装目录必须明确命名为WindTrace。' }
if ($InstallRoot -ne (Join-Path $ParentRoot 'WindTrace')) { throw '安装目录解析不一致。' }
$StageRoot=[IO.Path]::GetFullPath((Join-Path $ParentRoot "WindTrace_staging_$BackupSuffix"))
$BackupRoot=[IO.Path]::GetFullPath((Join-Path $ParentRoot "WindTrace_backup_$BackupSuffix"))
foreach ($Target in @($StageRoot,$BackupRoot)) {
    if (-not $Target.StartsWith($ParentRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '目标路径超出明确指定的安装父目录。' }
    if (Test-Path -LiteralPath $Target) { throw "保留已存在的目标，拒绝覆盖：$Target" }
}
if (Test-Path -LiteralPath $ReportFile) { throw '安装报告已存在。' }
$Manifest=Get-Content -LiteralPath (Join-Path $PackageRoot 'package_manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
if (-not (Test-Path -LiteralPath (Join-Path $PackageRoot 'WindTrace.exe'))) { throw '新包缺少WindTrace.exe。' }
$RunningHere=Get-Process -Name WindTrace -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase) }
if ($RunningHere) { throw '请先关闭安装目录中正在运行的WindTrace，旧程序尚未替换。' }
Copy-Item -LiteralPath $PackageRoot -Destination $StageRoot -Recurse
foreach ($Entry in $Manifest.files) {
    $Path=[IO.Path]::GetFullPath((Join-Path $StageRoot $Entry.path))
    if (-not $Path.StartsWith($StageRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '清单文件路径超出新包。' }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Entry.sha256) { throw "复制校验失败：$($Entry.path)" }
}
$OldHash=$null
if (Test-Path -LiteralPath (Join-Path $InstallRoot 'WindTrace.exe')) {
    $OldHash=(Get-FileHash -LiteralPath (Join-Path $InstallRoot 'WindTrace.exe')).Hash.ToLowerInvariant()
}
# 上面已验证绝对路径与边界；所有目录移动在同一PowerShell会话完成。
if (Test-Path -LiteralPath $InstallRoot) { Move-Item -LiteralPath $InstallRoot -Destination $BackupRoot }
try { Move-Item -LiteralPath $StageRoot -Destination $InstallRoot }
catch {
    if ((Test-Path -LiteralPath $BackupRoot) -and -not (Test-Path -LiteralPath $InstallRoot)) {
        Move-Item -LiteralPath $BackupRoot -Destination $InstallRoot
    }
    throw
}
$NewHash=(Get-FileHash -LiteralPath (Join-Path $InstallRoot 'WindTrace.exe')).Hash.ToLowerInvariant()
$ActualBackup=if (Test-Path -LiteralPath $BackupRoot) { $BackupRoot } else { $null }
$Report=[ordered]@{installed=$true;directory=$InstallRoot;backup=$ActualBackup;old_exe_sha256=$OldHash;new_exe_sha256=$NewHash;verified_files=$Manifest.files.Count;shortcuts_changed=$false}
$Report | ConvertTo-Json | Set-Content -LiteralPath $ReportFile -Encoding utf8
Write-Output "已安装：$(Join-Path $InstallRoot 'WindTrace.exe')"
if ($ActualBackup) { Write-Output "旧版备份：$ActualBackup" }
