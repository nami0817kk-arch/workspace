# ユーザーレベルスキル（~/.claude/skills）とこのディレクトリを同期する。
#
#   -Export : ~/.claude/skills → リポジトリ（編集後のバックアップ。普段はこちら）
#   -Install: リポジトリ → ~/.claude/skills（PC 作り直し時の復元）
#
# どちらも「リポジトリに存在するスキル」だけを対象にする。-Install が
# ~/.claude/skills 側にしかないスキルを消さないための制限（ミラーリングはしない）。
# このファイルは UTF-8 (BOM 付き) で保存すること（PowerShell 5.1 対策）。
param(
    [switch]$Export,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

if (-not ($Export -xor $Install)) {
    Write-Error "-Export か -Install のどちらか一方を指定してください。"
    exit 1
}

$repoDir = $PSScriptRoot
$userDir = Join-Path $env:USERPROFILE ".claude\skills"

if (-not (Test-Path $userDir)) {
    New-Item -ItemType Directory -Force -Path $userDir | Out-Null
}

# リポジトリ側にあるスキル名の一覧が同期対象
$skillNames = Get-ChildItem -Path $repoDir -Directory | Select-Object -ExpandProperty Name

foreach ($name in $skillNames) {
    if ($Export) {
        $src = Join-Path $userDir $name
        $dst = Join-Path $repoDir $name
        if (-not (Test-Path $src)) {
            Write-Warning "~/.claude/skills に無いためスキップ: $name"
            continue
        }
    } else {
        $src = Join-Path $repoDir $name
        $dst = Join-Path $userDir $name
    }

    # /E: サブディレクトリ込み。/PURGE は使わない（宛先の独自ファイルを消さない）。
    robocopy $src $dst /E /XD __pycache__ /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Error "コピー失敗 ($name): robocopy exit $LASTEXITCODE"
        exit 1
    }
    Write-Host "同期: $name"
}

# robocopy の成功コード(0-7)が残ったまま終わると呼び出し元が失敗と誤認する
exit 0
