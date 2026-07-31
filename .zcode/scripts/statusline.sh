#!/usr/bin/env bash
# ZCode status line: shows model, git branch, plan status, and context %.
#
# Adapted from the original Claude Code statusline. ZCode (like Claude Code)
# pipes a JSON session snapshot to stdin. Fields used:
#   .model.display_name      e.g. "GLM-5.2"
#   .workspace.current_dir   absolute path of the cwd
#
# NOTE: ZCode has no "permission_mode" concept (no bypassPermissions / plan /
# acceptEdits modes), so that badge was removed. The snapshot schema is read
# defensively — if a field is absent we fall back gracefully so the status
# line never blanks out.

set -euo pipefail

INPUT="$(cat)"

# Parse the snapshot fields in a single python3 invocation. The status line
# renders on every turn; avoid three forks when one suffices. Both the ZCode
# and Claude snapshot shapes are tolerated (model under .model.display_name).
parsed="$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
print((d.get('model') or {}).get('display_name', '?') or '?')
print((d.get('workspace') or {}).get('current_dir', '.') or '.')
" 2>/dev/null || printf '?\n.\n')"

model="$(printf '%s' "$parsed" | sed -n '1p')"
cwd="$(printf '%s' "$parsed" | sed -n '2p')"
[ -n "$model" ] || model="?"
[ -n "$cwd" ] && [ "$cwd" != "." ] || cwd="$(pwd)"

# Optional enrichment (branch, dirty count, plan status, context %).
# Wrapped in `set +e` so a probe failure can never blank the status line.
set +e
branch=""
dirty=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
    n="$(git -C "$cwd" status --porcelain 2>/dev/null | grep -c '.')"
    [ "${n:-0}" -gt 0 ] 2>/dev/null && dirty="±${n}"
fi

# Most-recent plan's status (DRAFT / APPROVED / COMPLETED).
plan_badge=""
latest_plan="$(ls -t "$cwd"/quality_reports/plans/*.md 2>/dev/null | head -1)"
if [ -n "$latest_plan" ]; then
    if   grep -qi 'COMPLETED' "$latest_plan" 2>/dev/null; then plan_badge="plan:done"
    elif grep -qi 'APPROVED'  "$latest_plan" 2>/dev/null; then plan_badge="plan:approved"
    elif grep -qi 'DRAFT'     "$latest_plan" 2>/dev/null; then plan_badge="plan:DRAFT"
    fi
fi

# Context % — best-effort, persisted by context-monitor.py under the session
# dir keyed by md5(project_dir)[:8]. Mirror context-monitor.py's get_session_dir():
# ZCODE_PROJECT_DIR (or CLAUDE_PROJECT_DIR fallback) set → hash it; unset/empty
# → the writer falls back to sessions/default/, so do the same.
ctx=""
proj_dir="${ZCODE_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
if [ -n "$proj_dir" ]; then
    hash="$(printf '%s' "$proj_dir" | python3 -c 'import sys,hashlib; print(hashlib.md5(sys.stdin.read().encode()).hexdigest()[:8])' 2>/dev/null)"
else
    hash="default"
fi
# Try ZCode's session path first, then the legacy Claude path.
pct_file="$HOME/.zcode/sessions/${hash}/context-pct.txt"
[ -f "$pct_file" ] || pct_file="$HOME/.claude/sessions/${hash}/context-pct.txt"
[ -f "$pct_file" ] && ctx="ctx $(cat "$pct_file" 2>/dev/null)%"
set -e

line="$model"
[ -n "$branch" ] && line="$line  @ $branch"
[ -n "$dirty" ] && line="$line $dirty"
[ -n "$plan_badge" ] && line="$line  $plan_badge"
[ -n "$ctx" ] && line="$line  $ctx"

printf '%s' "$line"
