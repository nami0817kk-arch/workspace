# 日次のランキング取得（このPCのタスクスケジューラから毎平日16:10に実行される）。
#
# kabutan が GitHub Actions の IP を 405 でブロックしているため、
# 取得だけは手元で行い、data/ を push する。push を受けた CI（daily-gainers-site.yml）が
# ビルド・X投稿・Cloudflare Pages への公開を行う。
#
# このスクリプトが動かなくなっても、CI 側の 17:00 JST の鮮度監視が
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

if ((Run "git pull --ff-only origin master") -ne 0) {
    Add-Content $log "FAILED: git pull"; exit 1
}
if ((Run "`"$repo\.venv\Scripts\python.exe`" src\build_site.py") -ne 0) {
    Add-Content $log "FAILED: build_site.py"; exit 1
}

Run "git add data" | Out-Null
cmd /c "git diff --cached --quiet"
if ($LASTEXITCODE -ne 0) {
    # 日本語メッセージは cmd 経由だと化けるため、UTF-8 ファイル渡しにする
    $msgFile = Join-Path $repo "commit-msg.tmp"
    [IO.File]::WriteAllText($msgFile, "chore: 値上がりランキングデータを更新", (New-Object Text.UTF8Encoding $false))
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
