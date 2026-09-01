#!/usr/bin/env bash
# 毎晩22時（タスクスケジューラ「workspace-wip-sweeper」）:
# dev/ 配下の全 git リポジトリ（workspace の worktree 含む）を走査し、
#   1) 未コミットの変更 → wip/<日時>-<ブランチ> ブランチとして退避 push
#   2) 未 push のコミット → そのブランチを push（master だけは wip/master-<日時> へ）
# 作業ツリー・インデックス・HEAD には一切触れない（commit-tree による snapshot）。
# 「push しないで止まっている作業」をゼロにするための保険であり、日中の手動 push の代替ではない。

set -u
DEV="/c/Users/なみ/dev"
LOG="$DEV/workspace/scripts/wip-sweeper.log"
TS=$(date +%Y%m%d-%H%M)

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

sweep_worktree() {
    local dir="$1"
    cd "$dir" || return
    git rev-parse --git-dir >/dev/null 2>&1 || return
    local origin
    origin=$(git remote get-url origin 2>/dev/null) || { log "SKIP(no-origin) $dir"; return; }
    local br
    br=$(git branch --show-current)
    [ -z "$br" ] && br="detached"

    # 1) 未コミットの変更を、作業ツリーに触れずに snapshot して push
    if [ -n "$(git status --porcelain)" ]; then
        local tmpidx tree commit ref
        tmpidx=$(mktemp)
        GIT_INDEX_FILE="$tmpidx" git read-tree HEAD 2>>"$LOG"
        GIT_INDEX_FILE="$tmpidx" git add -A 2>>"$LOG"
        tree=$(GIT_INDEX_FILE="$tmpidx" git write-tree 2>>"$LOG")
        rm -f "$tmpidx"
        if [ -n "$tree" ]; then
            commit=$(git commit-tree "$tree" -p HEAD -m "wip: 自動退避 $TS (branch: $br, dir: $dir)" 2>>"$LOG")
            ref="refs/heads/wip/$TS-$br"
            if git push -q origin "$commit:$ref" 2>>"$LOG"; then
                log "SNAPSHOT $dir ($br) -> wip/$TS-$br"
            else
                log "FAIL(snapshot-push) $dir ($br)"
            fi
        fi
    fi

    # 2) 未 push のコミット
    local ahead
    ahead=$(git rev-list --count "@{u}..HEAD" 2>/dev/null || echo "?")
    if [ "$ahead" = "?" ]; then
        # upstream 未設定のローカルブランチ → 同名で push（master 以外）
        if [ "$br" != "master" ] && [ "$br" != "main" ] && [ "$br" != "detached" ]; then
            git push -q -u origin "$br" 2>>"$LOG" && log "PUSH(new-branch) $dir ($br)"
        fi
    elif [ "$ahead" -gt 0 ] 2>/dev/null; then
        if [ "$br" = "master" ] || [ "$br" = "main" ]; then
            # master の未pushは本人の判断を待つ。退避ブランチにだけ写す
            git push -q origin "HEAD:refs/heads/wip/$TS-$br-ahead" 2>>"$LOG" \
                && log "AHEAD $dir ($br, $ahead件) -> wip/$TS-$br-ahead（masterは未push のまま）"
        else
            git push -q origin "$br" 2>>"$LOG" && log "PUSH $dir ($br, $ahead件)"
        fi
    fi
}

log "=== sweep start ==="
for repo in "$DEV"/*/; do
    [ -d "$repo/.git" ] || continue
    # メインの作業ツリー + 追加 worktree
    while IFS= read -r wt; do
        sweep_worktree "$wt"
    done < <(git -C "$repo" worktree list --porcelain | awk '/^worktree /{print substr($0,10)}')
done
log "=== sweep end ==="
