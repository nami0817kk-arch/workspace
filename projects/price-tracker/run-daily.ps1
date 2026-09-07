# 日次の価格取得（このPCのタスクスケジューラから毎日10:10に実行される）。
#
# 楽天ウェブサービスは Backend Service 型で「許可IPアドレス」からのリクエストしか
# 受け付けない。GitHub Actions のランナーはIPが固定できないため、取得だけは
# 自宅IPを持つこのPCで行い、data/ を push する。push を受けた CI
# (price-tracker-daily.yml) がサイトのビルド・公開を行う。
#
# このスクリプトが動かなくなっても（IP変更・PC停止など）、CI 側の鮮度監視が
# 「データが古い」と Issue で知らせてくれる（黙って止まらない）。
#
# 実装メモ: git は進捗を stderr に出すため、PowerShell 5.1 で `2>&1 | Add-Content`
# すると ErrorRecord 扱いになり誤って失敗する。リダイレクトは cmd 側で行う。

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo
$log = Join-Path $repo "run-daily.log"

# 失敗を Windows のデスクトップ通知で知らせる（kabu-agari-ranking と同じ方式）。
# CI の鮮度監視は最短でも1日遅れるうえ、取得が止まった日の価格は取り戻せない。
# 通知センターに残るので、実行時刻に画面を見ていなくても後から気づける。
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

Add-Content $log "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="

# 認証情報は .env から読む（gitignore 済み。キー名は .env.example にある）。
# 標準ライブラリのみの方針なので、Python 側ではなくここで環境変数に載せる。
$envFile = Join-Path $repo ".env"
if (-not (Test-Path $envFile)) {
    Add-Content $log "FAILED: .env がありません（.env.example をコピーして値を入れてください）"
    exit 1
}
foreach ($line in Get-Content $envFile -Encoding UTF8) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -lt 1) { continue }
    $name = $t.Substring(0, $i).Trim()
    $value = $t.Substring($i + 1).Trim()
    if ($value -ne "") { Set-Item -Path "env:$name" -Value $value }
}
foreach ($required in @("RAKUTEN_APP_ID", "RAKUTEN_ACCESS_KEY")) {
    if (-not (Get-Item -Path "env:$required" -ErrorAction SilentlyContinue)) {
        Add-Content $log "FAILED: $required が .env に入っていません"
        exit 1
    }
}

if ((Run "git pull --ff-only origin master") -ne 0) {
    Add-Content $log "FAILED: git pull"; exit 1
}

$python = Join-Path $repo ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = "python" }
if ((Run "`"$python`" fetch.py") -ne 0) {
    Add-Content $log "FAILED: fetch.py"
    # 自宅のグローバルIPは変わる。変わると楽天の許可IPと一致せず 403 で止まる
    # （2026-09-06 と 09-07 に実際に起きて2日分を取り逃した）。
    # 貼り替えるだけで直るので、通知に現在のIPを載せて手数を減らす。
    $tail = (Get-Content $log -Tail 80 -Encoding UTF8) -join "`n"
    if ($tail -match "CLIENT_IP_NOT_ALLOWED") {
        $ip = "（取得できませんでした）"
        try { $ip = Invoke-RestMethod https://api.ipify.org -TimeoutSec 10 } catch { }
        Notify "楽天の価格取得が止まりました（IP変更）" `
               "許可IPを $ip に更新してください。webservice.rakuten.co.jp/app/list の Edit から。"
    } else {
        Notify "楽天の価格取得が失敗しました" `
               "今日の価格は記録されていません。run-daily.log を確認してください。"
    }
    exit 1
}

Run "git add data" | Out-Null
cmd /c "git diff --cached --quiet"
if ($LASTEXITCODE -ne 0) {
    # 日本語メッセージは cmd 経由だと化けるため、UTF-8 ファイル渡しにする
    $msgFile = Join-Path $repo "commit-msg.tmp"
    [IO.File]::WriteAllText($msgFile, "chore(price-tracker): 価格履歴を記録", (New-Object Text.UTF8Encoding $false))
    if ((Run "git commit -F `"$msgFile`"") -ne 0) {
        Add-Content $log "FAILED: git commit"; exit 1
    }
    if ((Run "git push origin master") -ne 0) {
        Add-Content $log "FAILED: git push"; exit 1
    }
    Remove-Item $msgFile -ErrorAction SilentlyContinue
    Add-Content $log "pushed new data"
} else {
    Add-Content $log "no new data to commit"
}
Add-Content $log "OK"
