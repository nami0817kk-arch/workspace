# ジャンル調査を手元PCから実行する（結果は explore.log に出す）。
#
# 楽天ウェブサービスは Backend Service 型で「許可IPアドレス」からしか受け付けないため、
# CI からは実行できない。自宅IPを持つこのPCで回す。取得と同じ前提なので、
# ここが通れば run-daily.ps1 も通る（疎通確認を兼ねる）。
#
# 使い方:
#   .\run-explore.ps1                        最上位ジャンルを調べる
#   .\run-explore.ps1 --genre 100005         特定ジャンルの直下を掘る
#   .\run-explore.ps1 --show-fields          生レスポンスの項目名を見る（仕様変更の切り分け）
#
# 実装メモ: PowerShell 5.1 でネイティブコマンドの stderr を `2>&1` すると
# ErrorRecord に包まれて読めなくなる。リダイレクトは cmd 側で行う。

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo
$log = Join-Path $repo "explore.log"

# 認証情報は .env から読む。標準ライブラリのみの方針なので Python 側では読まない
# （run-daily.ps1 と同じ扱い）。
$envFile = Join-Path $repo ".env"
if (-not (Test-Path $envFile)) {
    Write-Host ".env がありません。.env.example をコピーして値を入れてください。" -ForegroundColor Red
    exit 1
}
foreach ($line in Get-Content $envFile -Encoding UTF8) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -lt 1) { continue }
    $value = $t.Substring($i + 1).Trim()
    if ($value -ne "") { Set-Item -Path "env:$($t.Substring(0, $i).Trim())" -Value $value }
}
foreach ($required in @("RAKUTEN_APP_ID", "RAKUTEN_ACCESS_KEY")) {
    if (-not (Get-Item -Path "env:$required" -ErrorAction SilentlyContinue)) {
        Write-Host "$required が .env に入っていません。" -ForegroundColor Red
        exit 1
    }
}

# 日本語が化けないようにしておく（cmd 経由でファイルに落とすため）。
$env:PYTHONIOENCODING = "utf-8"

$python = Join-Path $repo ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = "python" }

$extra = if ($Args) { " " + ($Args -join " ") } else { "" }
cmd /c "`"$python`" explore.py$extra > `"$log`" 2>&1"

Write-Host "結果: $log" -ForegroundColor Green
Get-Content $log -Encoding UTF8 -TotalCount 12
