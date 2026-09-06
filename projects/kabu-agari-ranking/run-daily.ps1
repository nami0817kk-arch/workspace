# 日次のランキング取得（このPCのタスクスケジューラから毎平日16:10に実行される）。
#
# kabutan が GitHub Actions の IP を 405 でブロックしているため、
# 取得だけは手元で行い、data/ を push する。push を受けた CI（kabu-daily.yml）が
# ビルド・X投稿・Cloudflare Pages への公開を行う。
#
# 失敗したときは Windows のデスクトップ通知で知らせる（Notify 関数）。
# 失敗の原因はたいていネットワーク断で、そのときは GitHub にもメールにも届かない。
# 通知だけはネットに依存しない手段でないと意味がないため、デスクトップ通知にしている。
# 補助として、CI 側の 17:00 JST の鮮度監視が「データが古い」と Issue で知らせる。
#
# 実装メモ: git は進捗を stderr に出すため、PowerShell 5.1 で `2>&1 | Add-Content`
# すると ErrorRecord 扱いになり誤って失敗する。リダイレクトは cmd 側で行う。

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo
$log = Join-Path $repo "run-daily.log"

# 失敗をユーザーに知らせる。ネット断でも必ず出したいので、
# GitHub でもメールでもなくデスクトップ通知を使う。
# 通知センターに残るので、実行時に画面を見ていなくても後から気づける。
# 通知自体が失敗しても本処理の結果は変えない（ログには残す）。
function Notify($title, $body) {
    Add-Content $log "NOTIFY: $title / $body"
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        # PowerShell 自身の AppId を借りる。専用のショートカットを登録しなくても通知が出る。
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$title</text><text>$body</text></binding></visual></toast>")
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch {
        Add-Content $log "NOTIFY FAILED: $($_.Exception.Message)"
    }
}

function Run($cmdline) {
    Add-Content $log ">> $cmdline"
    cmd /c "$cmdline >> `"$log`" 2>&1"
    return $LASTEXITCODE
}

# ネットワーク系のコマンドをリトライ付きで実行する。
# 16:10 の定時実行で DNS 解決が一時的に失敗する事象が続いたため
# （2026-09-03 / 09-04 に git pull が getaddrinfo 失敗で即死し、2営業日分を欠測）、
# 少し待って引き直す。恒常的な障害なら3回で諦めて従来どおり FAILED を残す。
function RunRetry($cmdline) {
    foreach ($wait in 0, 90, 180) {
        if ($wait -gt 0) {
            Add-Content $log "retry in ${wait}s: $cmdline"
            Start-Sleep -Seconds $wait
        }
        if ((Run $cmdline) -eq 0) { return 0 }
    }
    return 1
}

Add-Content $log "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="

if ((RunRetry "git pull --ff-only origin master") -ne 0) {
    Add-Content $log "FAILED: git pull"
    Notify "株ランキングの取得が失敗しました" "git pull がネットワークで失敗しました（3回リトライ済み）。今日のデータは取れていません。"
    exit 1
}
if ((Run "`"$repo\.venv\Scripts\python.exe`" src\build_site.py") -ne 0) {
    Add-Content $log "FAILED: build_site.py"
    Notify "株ランキングの取得が失敗しました" "build_site.py が失敗しました。kabutan から取得できていない可能性があります。run-daily.log を確認してください。"
    exit 1
}

Run "git add data" | Out-Null
cmd /c "git diff --cached --quiet"
if ($LASTEXITCODE -ne 0) {
    # 日本語メッセージは cmd 経由だと化けるため、UTF-8 ファイル渡しにする
    $msgFile = Join-Path $repo "commit-msg.tmp"
    [IO.File]::WriteAllText($msgFile, "chore: 値上がりランキングデータを更新", (New-Object Text.UTF8Encoding $false))
    if ((Run "git commit -F `"$msgFile`"") -ne 0) {
        Add-Content $log "FAILED: git commit"
        Notify "株ランキングの取得が失敗しました" "データは取れましたが git commit に失敗しました。run-daily.log を確認してください。"
        exit 1
    }
    if ((RunRetry "git push origin master") -ne 0) {
        # コミットはローカルに残っているので、翌営業日の git pull 後に push される
        Add-Content $log "FAILED: git push"
        Notify "株ランキングの公開が失敗しました" "取得は成功しましたが push できていません。コミットは手元に残っているので、ネット復旧後の実行で公開されます。"
        exit 1
    }
    Remove-Item $msgFile -ErrorAction SilentlyContinue
    Add-Content $log "pushed new data"
} else {
    Add-Content $log "no new data to commit"
}
Add-Content $log "OK"
