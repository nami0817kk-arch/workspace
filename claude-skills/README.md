# claude-skills — ユーザーレベルスキルのバックアップ

`C:\Users\なみ\.claude\skills\`（Claude Code がスキルを読む場所）の版管理コピー。
`.claude/` はどのリポジトリにも属さないため、モノレポ統合後もここだけが
バックアップの外にあった。それを解消する。

**正は `~/.claude/skills` 側**。スキルを直したらそちらを編集し、
`sync-skills.ps1` でこのディレクトリへ書き戻してコミットする。
（Claude Code はこのディレクトリを読まない。ここを直しても挙動は変わらない）

```powershell
# ~/.claude/skills → リポジトリ（普段はこちら。編集後のバックアップ）
powershell -ExecutionPolicy Bypass -File claude-skills\sync-skills.ps1 -Export

# リポジトリ → ~/.claude/skills（PC を作り直したときの復元）
powershell -ExecutionPolicy Bypass -File claude-skills\sync-skills.ps1 -Install
```

- 同期は**このリポジトリに存在するスキルのみ**が対象。`-Install` は
  `~/.claude/skills` にしかないスキルを消さない（`robocopy /MIR` は使わない）。
- `__pycache__` は同期対象外。
- スキルに API キーやトークンを書かないこと。ここは push される。
  キーが要るスキルは、各PJTの `.env` を参照する形にする。
