<#
.SYNOPSIS
    リモートデバッグを有効にした Chrome を起動する(Windows)。

.DESCRIPTION
    src/browser/local_chrome.py の接続先になる Chrome を立ち上げる。
    既定では専用プロファイルを使うため、普段使いの Chrome を閉じる必要はない。
    普段のプロファイル(ログイン済みセッションや拡張機能)をそのまま使いたい場合は
    -UseDefaultProfile を付ける。その場合は先に Chrome を完全に終了しておくこと。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\start-chrome-debug.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\start-chrome-debug.ps1 -UseDefaultProfile
#>
param(
    [int]$Port = 9222,
    [string]$StartUrl = "about:blank",
    [switch]$UseDefaultProfile
)

$ErrorActionPreference = "Stop"

$candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$chrome = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) {
    Write-Error "chrome.exe が見つかりません。探した場所:`n  $($candidates -join "`n  ")"
    exit 1
}

$chromeArgs = @("--remote-debugging-port=$Port")

if ($UseDefaultProfile) {
    $running = Get-Process chrome -ErrorAction SilentlyContinue
    if ($running) {
        Write-Error "Chrome が起動中です。既定プロファイルを使う場合は Chrome を完全に終了してから実行してください。"
        exit 1
    }
    Write-Host "既定プロファイルで起動します(ログイン状態と拡張機能を引き継ぎます)。"
} else {
    $profileDir = Join-Path $env:LOCALAPPDATA "ai-lab\chrome-debug-profile"
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    $chromeArgs += "--user-data-dir=$profileDir"
    Write-Host "専用プロファイルで起動します: $profileDir"
}

$chromeArgs += $StartUrl

Start-Process -FilePath $chrome -ArgumentList $chromeArgs

Write-Host ""
Write-Host "Chrome をデバッグポート $Port で起動しました。"
Write-Host "接続確認: http://127.0.0.1:$Port/json/version"
Write-Host "操作するには: python -m src.browser.local_chrome --list"
