# Chrome 擴充打包：產出可直接載入的資料夾與可散布的 zip
#   用法：powershell -ExecutionPolicy Bypass -File build\build-chrome.ps1
# 註：本檔以 UTF-8 with BOM 儲存，Windows PowerShell 5.1 才能正確讀取中文

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$out  = Join-Path $root 'dist\注音亂碼偵測-Chrome擴充'
$zip  = Join-Path $root 'dist\注音亂碼偵測-Chrome擴充.zip'

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out -Force | Out-Null

Copy-Item (Join-Path $root 'manifest.json') $out
Copy-Item (Join-Path $root 'src') (Join-Path $out 'src') -Recurse
# 擴充本身的說明（專案根目錄的 README 是整個專案的總覽）
Copy-Item (Join-Path $root 'docs\readme-chrome.md') (Join-Path $out 'README.md')
Copy-Item (Join-Path $root 'docs\NOTICE.md') (Join-Path $out 'NOTICE.md')

# ZIP 規格要求路徑分隔符是正斜線，但在 Windows PowerShell 5.1（.NET Framework）上
# Compress-Archive 與 ZipFile.CreateFromDirectory 都會寫成反斜線（src\content\content.js）。
# Chrome 線上應用程式商店會把它當成「檔名含反斜線的單一檔案」，
# manifest 引用的 src/... 路徑就全部找不到 —— 擴充直接壞掉。
# 所以逐一建立項目並自己指定正斜線。
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
  Get-ChildItem $out -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($out.Length + 1).Replace('\', '/')
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $rel)
  }
} finally { $archive.Dispose() }

Write-Host "完成："
Get-ChildItem $out -File | ForEach-Object { "  {0,-22} {1,8:N0} KB" -f $_.Name, ($_.Length / 1KB) }
"  src\ 內含 {0} 個檔案" -f (Get-ChildItem (Join-Path $out 'src') -Recurse -File).Count
"  zip 大小：{0:N0} KB" -f ((Get-Item $zip).Length / 1KB)
