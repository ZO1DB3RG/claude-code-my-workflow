---
name: invoke-agent
description: Invoke one of the repo's specialist subagents by name using ZCode's Agent tool with persona injection. Use when a task calls for a named specialist (editor, methods-referee, claim-verifier, quarto-critic, verifier, proofreader, etc.) but ZCode's Agent tool only accepts `general-purpose` / `Explore` as `subagent_type`. This skill reads the agent's persona from `.zcode/agents/<name>.md` and assembles the correct Agent call. Also the building block fan-out skills use to spawn their reviewers.
argument-hint: "<agent-name> [\"task description\"] [--read-only] [--list]"
allowed-tools: ["Read", "Glob", "Grep", "Agent"]
---

# Invoke a Specialist Subagent (persona injection)

ZCode's `Agent` tool only accepts `subagent_type: general-purpose` or
`subagent_type: Explore` — it does **not** register the 18 specialists in
`.zcode/agents/` as custom types (the plugin `agents` field is recorded but not
executed in this ZCode build; see `.zcode/references/zcode-execution-overlay.md`).
This skill is the canonical bridge: it loads a specialist's persona and spawns
the agent with the right built-in type.

## Arguments

- `$0` — the agent name (e.g. `methods-referee`, `claim-verifier`, `verifier`).
  Must match a `.zcode/agents/<name>.md` file (without the `.md`).
- `$1..$N` — the task description / payload the agent should work on.
- `--read-only` — force `subagent_type: Explore` (no file writes) even if the
  agent's `tools:` include Write/Edit. Use for reviewers.
- `--list` — print the roster of available specialists and exit (no spawn).

## Step 0: Roster (`--list`)

If `--list` is present, glob `.zcode/agents/*.md`, print each agent's `name` +
`description` (from frontmatter) + its role-weight tier, and stop. Do not spawn.

## Step 1: Resolve the agent

1. Read `.zcode/agents/<name>.md`. If it does not exist, halt with the roster
   (Step 0 output) and ask the user to pick a real name.
2. Split the file into **frontmatter** (between the `---` fences) and **body**
   (everything after the second `---`). The **body is the persona** — the role,
   protocol, report format, output schema, "what would change my mind" clauses.
3. From the frontmatter, read:
   - `tools:` — the agent's intended tool set.
   - `model:` — informational only (all resolve to the configured model; see
     `.zcode/references/model-versions.md`). Do NOT pass it as a constraint.

## Step 2: Decide `subagent_type`

- If `--read-only` was passed → `subagent_type: Explore` (read-only, no writes).
- Else if the agent's `tools:` contains **only** read-style tools
  (`Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`) and no `Write`/`Edit`/`Bash`
  → `subagent_type: Explore` is the safer default.
- Else (the agent writes files or runs Bash, e.g. `quarto-fixer`,
  `beamer-translator`, `verifier`) → `subagent_type: general-purpose`.

For fan-out reviewers (the read-only fleet — referees, critics, auditors,
proofreader, claim-verifier), **always use `Explore`** unless the reviewer must
run a command.

## Step 3: Assemble the prompt

The `Agent` call's `prompt` is composed in this exact order:

1. **The persona body** (from Step 1) — verbatim, the whole thing after the
   frontmatter. This carries the role, calibration, dimensions, report format,
   and any "what would change my mind" / output-schema requirements.
2. A separator line: `---`.
3. **The task payload** — the `$1..$N` arguments:
   - The artifact path(s) to work on (absolute paths).
   - The specific lens / question / disposition / peeves (if the persona calls
     for calibration, e.g. referees need their disposition + journal).
   - Where to write its report (file path), if the persona specifies an output
     location.
   - A closing instruction to return findings in the shared `FINDING` /
     `SCORECARD` schema (`.zcode/references/orchestration-schemas.md`) when the
     agent is part of a review fan-out.

## Step 4: Spawn

Make **one `Agent` tool call** with:
- `subagent_type`: the value from Step 2.
- `description`: a 3-5 word label of what the agent is doing.
- `prompt`: the composed prompt from Step 3.
- `model`: omit (or set to the configured default) — tier is a persona weight,
  not a model pin.

Wait for the agent's report. Reduce over it per
`.zcode/rules/orchestrator-protocol.md` if this is part of a fan-out.

## Fan-out (multiple agents)

When the caller needs N specialists in parallel (the orchestrator's fan-out
primitive), make **N `Agent` tool calls in a single message** — one per
specialist, each following Steps 1-4 independently. They run concurrently with
fresh isolated contexts (ZCode's default). This is exactly what
`/seven-pass-review`, `/review-paper --peer`, `/qa-quarto`, `/deep-audit`, and
`/slide-excellence` do; this skill is the shared helper they could delegate to.

## Constraints

- Subagents must **not** load `browser-use:control-browser` (main-agent-only).
  If a specialist needs browser work, it returns the URL/step and the main agent
  performs it.
- A forked subagent **cannot stop to ask the user a question** — resolve every
  interactive choice (journal, disposition, N) before spawning (the
  `RUN_CONFIG` pattern, `.zcode/references/orchestration-schemas.md` §5).

## Cross-references

- `.zcode/references/zcode-execution-overlay.md` — the translation table this skill implements.
- `.zcode/references/agent-fleet.md` — the roster + role weights.
- `.zcode/rules/orchestrator-protocol.md` — fan-out → reduce → judge → loop.
- `.zcode/references/orchestration-schemas.md` — FINDING/SCORECARD contract.
