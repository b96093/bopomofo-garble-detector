# 桌面版打包：把 app.ahk 編譯成單一 exe，並備妥散布資料夾
#   用法：powershell -ExecutionPolicy Bypass -File desktop\build.ps1
# 需先安裝 Ahk2Exe（AutoHotkey Dash → 安裝編譯器，或執行
# C:\Program Files\AutoHotkey\UX\install-ahk2exe.ahk）

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

$candidates = @(
  'C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe',
  'C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe',
  "$env:LOCALAPPDATA\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
)
$ahk2exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahk2exe) {
  Write-Error "找不到 Ahk2Exe 編譯器。請先執行 C:\Program Files\AutoHotkey\UX\install-ahk2exe.ahk"
}

$base = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
$out  = Join-Path $root 'dist\注音亂碼偵測-桌面版'
$exe  = Join-Path $out '注音亂碼偵測.exe'

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out -Force | Out-Null

Write-Host "編譯中…（#Include 的 engine/draw/english 會一起打包進 exe）"
& $ahk2exe /in (Join-Path $here 'app.ahk') /out $exe /base $base /icon (Join-Path $here 'icon.ico')
if (-not (Test-Path $exe)) { Write-Error "編譯失敗，未產生 exe" }

# 執行時需要的外部檔案
Copy-Item (Join-Path $here 'dict.txt') $out
Copy-Item (Join-Path $here 'icon.ico') $out
Copy-Item (Join-Path $here 'README.md') $out
Copy-Item (Join-Path $root 'docs\NOTICE.md') $out

$zip = Join-Path $root 'dist\注音亂碼偵測-桌面版.zip'
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -Force

Write-Host "`n完成："
Get-ChildItem $out -File | ForEach-Object { "  {0,-24} {1,8:N0} KB" -f $_.Name, ($_.Length / 1KB) }
"  zip 大小：{0:N0} KB" -f ((Get-Item $zip).Length / 1KB)
