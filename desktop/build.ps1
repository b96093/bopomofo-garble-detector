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

Write-Host "編譯中…（#Include 的 engine/draw/uia 會一起打包進 exe）"
& $ahk2exe /in (Join-Path $here 'app.ahk') /out $exe /base $base /icon (Join-Path $here 'icon.ico')
# Ahk2Exe 有時會在回報成功之前就先返回，等檔案真的出現再繼續
$waited = 0
while (-not (Test-Path $exe) -and $waited -lt 30) {
  Start-Sleep -Milliseconds 500
  $waited++
}
if (-not (Test-Path $exe)) { Write-Error "編譯失敗，未產生 exe" }

# 執行時需要的外部檔案
Copy-Item (Join-Path $here 'dict.txt') $out
Copy-Item (Join-Path $here 'icon.ico') $out
Copy-Item (Join-Path $here 'icon-paused.ico') $out   # 暫停時的灰階系統列圖示
Copy-Item (Join-Path $here 'README.md') $out
Copy-Item (Join-Path $root 'docs\NOTICE.md') $out

# 檔名用 ASCII：GitHub Release 的附件會把非 ASCII 字元換成「-」，
# 中文檔名上傳後會變成「-.zip」，使用者下載完全認不出是什麼。
$zip = Join-Path $root 'dist\bopomofo-garble-detector-desktop.zip'
# 同 build-chrome.ps1：Compress-Archive 與 ZipFile.CreateFromDirectory 在
# .NET Framework 上都會寫出反斜線路徑，不符 ZIP 規格，故逐一建立項目
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
  # 排除 settings.ini：若在打包前執行過 exe 測試，這個檔會留在輸出資料夾。
  # 它帶有 welcomed=1，包進去會讓每個使用者都跳過第一次開啟的使用說明。
  Get-ChildItem $out -Recurse -File | Where-Object { $_.Name -ne 'settings.ini' } | ForEach-Object {
    $rel = $_.FullName.Substring($out.Length + 1).Replace('\', '/')
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel)
  }
} finally { $archive.Dispose() }

Write-Host "`n完成："
Get-ChildItem $out -File | ForEach-Object { "  {0,-24} {1,8:N0} KB" -f $_.Name, ($_.Length / 1KB) }
"  zip 大小：{0:N0} KB" -f ((Get-Item $zip).Length / 1KB)
