# 毎日15:30の「過去の概要欄の直し」（タスクスケジューラ yt-desc-fix から呼ぶ。2026-09-30）
# 枠が16時に戻る前に、その日の余りを使い切る（ユーザー「16時前に」「apiのあまりで実施する」）。
# 16時までの投稿のぶん 1,000 だけ残す
$env:PYTHONIOENCODING = 'utf-8'
Set-Location $PSScriptRoot\..
New-Item -ItemType Directory -Force output\logs | Out-Null
$log = 'output\logs\desc_fix.log'
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm')" | Out-File -FilePath $log -Append -Encoding utf8
$out = python tools\fix_old_descriptions.py --limit 1000 --reserve 1000 2>&1 | Out-String
$out | Out-File -FilePath $log -Append -Encoding utf8
# 全部済んだら、このタスク自身を消す
if ($out -match '全部済んでいます') { schtasks /Delete /TN yt-desc-fix /F | Out-Null; "タスクを消しました" | Out-File -FilePath $log -Append -Encoding utf8 }
