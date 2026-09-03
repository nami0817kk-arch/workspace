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
    Add-Content $log "FAILED: fetch.py"; exit 1
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
