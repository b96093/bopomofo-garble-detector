# Chrome 擴充打包：產出可直接載入的資料夾與可散布的 zip
#   用法：powershell -ExecutionPolicy Bypass -File build\build-chrome.ps1
# 註：本檔以 UTF-8 with BOM 儲存，Windows PowerShell 5.1 才能正確讀取中文

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$out  = Join-Path $root 'dist\文字亂碼偵測'
$zip  = Join-Path $root 'dist\文字亂碼偵測.zip'

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out -Force | Out-Null

Copy-Item (Join-Path $root 'manifest.json') $out
Copy-Item (Join-Path $root 'src') (Join-Path $out 'src') -Recurse
# 擴充本身的說明（專案根目錄的 README 是整個專案的總覽）
Copy-Item (Join-Path $root 'docs\readme-chrome.md') (Join-Path $out 'README.md')
Copy-Item (Join-Path $root 'docs\NOTICE.md') (Join-Path $out 'NOTICE.md')

Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -Force

Write-Host "完成："
Get-ChildItem $out -File | ForEach-Object { "  {0,-22} {1,8:N0} KB" -f $_.Name, ($_.Length / 1KB) }
"  src\ 內含 {0} 個檔案" -f (Get-ChildItem (Join-Path $out 'src') -Recurse -File).Count
"  zip 大小：{0:N0} KB" -f ((Get-Item $zip).Length / 1KB)
