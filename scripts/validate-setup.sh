#!/usr/bin/env bash
# =============================================================================
# validate-setup.sh — Verify all dependencies for the academic workflow
#
# Run this after forking the repo to confirm your environment is ready.
# Exits 0 if all required tools are found; non-zero otherwise.
# =============================================================================

set -uo pipefail

# ANSI colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass=0
warn=0
fail=0

echo ""
echo -e "${BOLD}Validating ZCode Academic Workflow setup...${RESET}"
echo ""

check_required() {
    local name="$1"
    local cmd="$2"
    local install_url="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${RESET} $name found: $("$cmd" --version 2>&1 | head -n1)"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}✗${RESET} $name NOT FOUND — install: ${install_url}"
        fail=$((fail + 1))
    fi
}

check_optional() {
    local name="$1"
    local cmd="$2"
    local install_url="$3"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${RESET} $name found: $("$cmd" --version 2>&1 | head -n1)"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}⚠${RESET} $name not found (optional) — install: ${install_url}"
        warn=$((warn + 1))
    fi
}

echo -e "${BOLD}Required tools:${RESET}"
check_required "git"          "git"      "https://git-scm.com/downloads"
check_required "Python 3"     "python3"  "https://python.org (needed for hooks)"
echo ""

echo -e "${BOLD}Recommended tools:${RESET}"
check_optional "R"            "R"        "https://www.r-project.org/"
check_optional "GitHub CLI"   "gh"       "https://cli.github.com/"
echo ""

echo -e "${BOLD}Agent runtime (ZCode):${RESET}"
# The workflow is driven by an agent runtime. A CLI on PATH is one form; the
# ZCode desktop app (or a ZCode remote session driving this machine) also
# counts and is NOT detectable here — so absence is a warning, never a failure.
if command -v zcode >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} ZCode CLI found: $(zcode --version 2>&1 | head -n1)"
    pass=$((pass + 1))
elif command -v claude >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} agent CLI found on PATH: claude ($(claude --version 2>&1 | head -n1))"
    warn=$((warn + 1))
else
    echo -e "  ${YELLOW}⚠${RESET} no agent CLI on PATH (zcode / claude)."
    echo -e "    If you drive this repo from the ZCode desktop app or a ZCode remote"
    echo -e "    session, this is fine — only a bare terminal needs a CLI."
    warn=$((warn + 1))
fi
echo ""

echo -e "${BOLD}Slides toolchain (skip if you only do papers / data analysis):${RESET}"
check_optional "XeLaTeX"      "xelatex"  "https://tug.org/texlive/ (Beamer .tex only)"
check_optional "Quarto"       "quarto"   "https://quarto.org/docs/get-started/ (RevealJS .qmd only)"
echo ""

echo -e "${BOLD}Git configuration:${RESET}"
if command -v git >/dev/null 2>&1; then
    git_name=$(git config user.name 2>/dev/null || true)
    git_email=$(git config user.email 2>/dev/null || true)
    if [ -n "$git_name" ] && [ -n "$git_email" ]; then
        echo -e "  ${GREEN}✓${RESET} git user: $git_name <$git_email>"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}⚠${RESET} git user.name / user.email not set"
        echo -e "    Run: git config --global user.name \"Your Name\""
        echo -e "    Run: git config --global user.email \"you@example.com\""
        warn=$((warn + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${RESET} skipped — install git first (see required tools above)"
    warn=$((warn + 1))
fi
echo ""

echo -e "${BOLD}ZCode hooks:${RESET}"
hook_dir="$(dirname "$0")/../.zcode/hooks"
if [ -d "$hook_dir" ]; then
    non_exec=$(find "$hook_dir" -maxdepth 1 \( -name "*.py" -o -name "*.sh" \) ! -perm -u+x 2>/dev/null | wc -l | tr -d ' ')
    if [ "$non_exec" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} All hook scripts are executable"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}⚠${RESET} $non_exec hook script(s) not executable"
        echo -e "    Fix: chmod +x .zcode/hooks/*.py .zcode/hooks/*.sh"
        warn=$((warn + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${RESET} .zcode/hooks/ directory not found (are you in the project root?)"
    warn=$((warn + 1))
fi

echo ""
echo -e "${BOLD}Git pre-commit gate (v2.0):${RESET}"
pchook="$(dirname "$0")/../.githooks/pre-commit"
if [ -f "$pchook" ]; then
    if [ -x "$pchook" ]; then
        echo -e "  ${GREEN}✓${RESET} .githooks/pre-commit is executable"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}⚠${RESET} .githooks/pre-commit is NOT executable — git silently skips it, disabling the gate"
        echo -e "    Fix: chmod +x .githooks/pre-commit  (or re-run ./scripts/install-hooks.sh)"
        warn=$((warn + 1))
    fi
    if command -v git >/dev/null 2>&1; then
        if [ "$(git config core.hooksPath 2>/dev/null || true)" = ".githooks" ]; then
            echo -e "  ${GREEN}✓${RESET} core.hooksPath → .githooks (gate active on every commit)"
        else
            echo -e "  ${YELLOW}⚠${RESET} pre-commit gate not activated — run ./scripts/install-hooks.sh"
            warn=$((warn + 1))
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${RESET} .githooks/pre-commit not found"
    warn=$((warn + 1))
fi
echo ""

echo -e "${BOLD}Palette sync (LaTeX ↔ SCSS):${RESET}"
palette_script="$(dirname "$0")/check-palette-sync.sh"
if [ -x "$palette_script" ]; then
    # Rely on the helper's exit code — stable contract, not text matching.
    # 0 = in sync, 1 = divergence.
    if "$palette_script" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${RESET} Preambles/header.tex ↔ Quarto/theme-template.scss agree on the core palette"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}⚠${RESET} Palette drift — run ./scripts/check-palette-sync.sh for details"
        warn=$((warn + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${RESET} scripts/check-palette-sync.sh missing or not executable — skipping"
    warn=$((warn + 1))
fi
echo ""

echo -e "${BOLD}Summary:${RESET} ${GREEN}${pass} passed${RESET}, ${YELLOW}${warn} warnings${RESET}, ${RED}${fail} failed${RESET}"
echo ""

# Which tools did we actually find? Gate the next-step suggestions accordingly.
# Use string flags (not command names) so shellcheck is happy and `if` bodies
# read naturally.
has_agent="false";   { command -v zcode >/dev/null 2>&1 || command -v claude >/dev/null 2>&1; } && has_agent="true"
has_xelatex="false"; command -v xelatex >/dev/null 2>&1 && has_xelatex="true"
has_quarto="false";  command -v quarto  >/dev/null 2>&1 && has_quarto="true"
has_r="false";       command -v R       >/dev/null 2>&1 && has_r="true"

if [ "$fail" -gt 0 ]; then
    echo -e "${RED}Some required tools are missing.${RESET}"
    echo ""
    echo -e "${BOLD}What you CAN do right now:${RESET}"
    echo "  - Papers / data analysis need only: git + python3 + (R). Install those first."
    if [ "$has_agent" = "true" ]; then
        echo "  - Agent CLI on PATH:                     zcode / claude"
    else
        echo "  - Drive the repo from the ZCode desktop app or a ZCode remote session"
        echo "    (no CLI needed on this machine in that case)."
    fi
    echo ""
    echo "  ${BOLD}Inside the agent${RESET} (slash-commands, NOT shell commands):"
    if [ "$has_r" = "true" ]; then
        echo "    /data-analysis             # orchestrate R analysis (no LaTeX needed)"
    fi
    if [ "$has_quarto" = "true" ]; then
        echo "    /deploy HelloWorld         # render Quarto sample"
    fi
    if [ "$has_xelatex" = "true" ]; then
        echo "    /compile-latex HelloWorld  # compile Beamer sample"
    fi
    if [ "$has_xelatex" != "true" ]; then
        echo ""
        echo "  (Beamer workflow disabled until you install XeLaTeX: https://tug.org/texlive/)"
    fi
    if [ "$has_quarto" != "true" ]; then
        echo "  (Quarto deploy disabled until you install Quarto: https://quarto.org/docs/get-started/)"
    fi
    echo ""
    echo -e "${BOLD}Next:${RESET} install the missing required tool(s) listed above, then re-run this script."
    exit 1
fi

echo -e "${GREEN}Setup looks good!${RESET} Next steps:"
echo "  1. Open ZCode in this directory — it auto-loads .zcode/ + AGENTS.md"
if [ "$has_xelatex" = "true" ]; then
    echo "  2. Compile the sample deck:              /compile-latex HelloWorld"
fi
if [ "$has_quarto" = "true" ]; then
    echo "  3. Deploy the Quarto sample:             /deploy HelloWorld"
fi
if [ "$has_r" = "true" ]; then
    echo "  4. Or go straight to research:           /data-analysis \"<dataset or goal>\""
fi
echo ""
exit 0
