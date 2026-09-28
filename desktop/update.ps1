# 注音亂碼偵測 —— 一鍵更新
#
# 雙擊同資料夾的「更新到最新版.cmd」即可執行。
# 做的事：查 GitHub 最新版 → 下載 → 關掉舊版 → 覆蓋 → 重開。
#
# 程式本身（exe）仍然完全不連網。只有你主動執行這支腳本時，它才會連上 GitHub
# 讀取版本資訊與下載檔案 —— 跟你自己開瀏覽器去下載頁是同一回事。
#
# settings.ini 不在下載的壓縮檔裡，所以你的設定不會被覆蓋。

$ErrorActionPreference = 'Stop'
$repo = 'b96093/bopomofo-garble-detector'
$name = 'bopomofo-garble-detector-desktop.zip'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

function Main {
    $dir = Split-Path -Parent $PSCommandPath
    $exe = Join-Path $dir '注音亂碼偵測.exe'

    if (-not (Test-Path $exe)) {
        Say "這個資料夾裡沒有 注音亂碼偵測.exe：" 'Red'
        Say "  $dir" 'Red'
        Say "請把這支更新程式放在跟 exe 同一個資料夾裡。" 'Red'
        return
    }
    $cur = (Get-Item $exe).VersionInfo.ProductVersion
    Say "目前版本：$cur"

    Say "查詢最新版…"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" `
                                 -Headers @{ 'User-Agent' = 'bopomofo-updater' }
    } catch {
        Say "連不上 GitHub：$($_.Exception.Message)" 'Red'
        Say "可以稍後再試，或到發布頁手動下載。" 'Yellow'
        return
    }
    $latest = $rel.tag_name -replace '^v', ''
    $asset  = $rel.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $asset) {
        Say "最新版 $($rel.tag_name) 裡找不到 $name，請到發布頁手動下載。" 'Red'
        return
    }
    Say "最新版本：$latest"

    # 只在「遠端比本機新」時才動手。用不相等判斷會把本機的測試版降級。
    $newer = $false
    try   { $newer = ([version]$latest -gt [version]$cur) }
    catch { $newer = ($latest -ne $cur) }      # 版本號格式不認得時，退回不相等判斷
    if (-not $newer) {
        Say ""
        if ($latest -eq $cur) { Say "已經是最新版，不用更新。" 'Green' }
        else                  { Say "本機的 $cur 比發布的 $latest 還新，不動它。" 'Yellow' }
        return
    }

    # 先下載解壓到暫存，全部成功了才碰安裝資料夾 —— 中途失敗時原本的版本完好無損
    $tmp = Join-Path $env:TEMP ("bgd-update-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp $name
        Say "下載中…（$([int]($asset.size / 1KB)) KB）"
        Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath "$tmp\new" -Force

        $newExe = Join-Path "$tmp\new" '注音亂碼偵測.exe'
        if (-not (Test-Path $newExe)) { throw "下載的壓縮檔裡沒有 注音亂碼偵測.exe" }
        Say "SHA256：$((Get-FileHash $newExe -Algorithm SHA256).Hash)" 'DarkGray'
        Say "（可與發行說明上的校驗碼比對）" 'DarkGray'

        # 關掉所有執行中的實例 —— 只關這個資料夾的還不夠，
        # 別的資料夾留著一個舊版，新版啟動時一樣會被單一實例擋下。
        $running = @(Get-Process -Name '注音亂碼偵測' -ErrorAction SilentlyContinue)
        if ($running.Count -gt 0) {
            Say "關閉執行中的 $($running.Count) 個實例…"
            $running | Stop-Process -Force
            Start-Sleep -Seconds 2
        }

        Say "覆蓋檔案…"
        Get-ChildItem "$tmp\new" -File | ForEach-Object { Copy-Item $_.FullName $dir -Force }

        Say ""
        Say "已更新：$cur → $((Get-Item $exe).VersionInfo.ProductVersion)" 'Green'

        Say "重新啟動…"
        Start-Process $exe -WorkingDirectory $dir
        Start-Sleep -Seconds 3
        if (Get-Process -Name '注音亂碼偵測' -ErrorAction SilentlyContinue) {
            Say "啟動成功。詞庫載入需要幾秒，系統列出現圖示就好了。" 'Green'
        } else {
            Say "沒有自動啟動起來，請手動雙擊桌面捷徑。" 'Yellow'
        }
    }
    catch {
        Say ""
        Say "更新失敗：$($_.Exception.Message)" 'Red'
        Say "原本的版本沒有被動到，可以照常使用。" 'Yellow'
    }
    finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Main
# 雙擊執行時視窗會在腳本結束後立刻關掉，留一下讓人看得到結果。
# 自動化呼叫（輸入被導向）時不擋住。
if (-not [Console]::IsInputRedirected) {
    Write-Host ""
    Read-Host "按 Enter 關閉" | Out-Null
}
