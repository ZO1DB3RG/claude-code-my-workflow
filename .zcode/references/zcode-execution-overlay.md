# ZCode Execution Overlay — fan-out translation rules

> **Read this whenever a skill says to spawn a `Task` / `subagent_type=X` /
> `context: fork`.** This file is the single source of truth for how the
> Claude-Code fan-out vocabulary maps onto ZCode's `Agent` tool. It is a
> `references/` file (not counted as a skill/rule/agent).

This fork was adapted from a Claude Code template. The skills' prose still
uses Claude-Code vocabulary (`Task`, `subagent_type=editor`, `context: fork`,
`fresh forked subagent`). In ZCode the **runtime is equivalent**, but the
spelling differs. Apply the rules below verbatim.

## The translation table

| Claude-Code vocabulary in skill prose | What you actually do in ZCode |
|---|---|
| "spawn N `Task` calls in parallel" / "in a single message" | Make **N `Agent` tool calls in one assistant message**. They run concurrently and each returns its report. (`Task` ↔ `Agent` is auto-aliased, but use `Agent`.) |
| "`context: fork`" / "fresh forked subagent" | **Nothing to set.** Fresh isolated context is ZCode's *default* subagent behavior — every `Agent` call gets its own child session with no parent history. |
| "`subagent_type: <specialist>`" (e.g. `editor`, `methods-referee`, `claim-verifier`, `quarto-critic`, `verifier`) | **Persona injection (Plan B, default):** spawn `subagent_type: general-purpose`, and in the `prompt` **prepend the full system-prompt body of `.zcode/agents/<specialist>.md`** (its persona, role, report format, output-schema/"what would change my mind" requirements). For a read-only reviewer, `subagent_type: Explore` is the stricter choice (guarantees no writes). |
| "the reviewer is read-only" | Prefer `subagent_type: Explore`; otherwise add an explicit "do not modify any files" line in the prompt. |
| "`Task` with `subagent_type=general-purpose`" | `Agent` with `subagent_type: general-purpose`. (No change in meaning.) |
| model tier (`model: opus/sonnet/haiku`) | **Ignored by the runtime** — all agents resolve to the single configured model. The tier maps to a *role weight* ([`model-routing.md`](../rules/model-routing.md)), expressed via persona strength, not model selection. |
| `effort:` | **No equivalent.** Ignore. |

## Persona-injection recipe (the load-bearing one)

When a skill says "spawn the `methods-referee` agent", do exactly this:

1. **Read** `.zcode/agents/methods-referee.md` and capture everything **after**
   its frontmatter `---` — that body *is* the persona (role, calibration,
   dimensions, "what would change my mind", report format).
2. **Compose the `Agent` prompt** as: that persona body, then a separator,
   then the task-specific payload (manuscript path, disposition/peeves,
   output-path instruction, the shared `FINDING`/`SCORECARD` schema closure
   from [`orchestration-schemas.md`](orchestration-schemas.md)).
3. **Spawn** with `subagent_type: general-purpose` (or `Explore` if the agent
   is read-only — `methods-referee` is). Wait for its report.
4. The reviewer's return value is its written report (and/or the file it was
   told to write). Reduce over it per [`orchestrator-protocol.md`](../rules/orchestrator-protocol.md).

This preserves every behavioral property the original `Task(subagent_type=X,
context: fork)` had: isolated fresh context, the specialist's full persona,
and structured output. The only thing that changes is *where the persona
comes from* — injected in the prompt instead of looked up by type name.

## Plan A (optional, only if Plan B is insufficient)

Package `.zcode/agents/` as a local plugin so the 18 specialists become real
`subagent_type` values:

```
.zcode-plugin/plugin.json   # { "name": "academic-workflow-agents",
                             #    "agents": "agents" }
```

Then `subagent_type: methods-referee` works directly. Not enabled by default —
Plan B is lower-friction and achieves the same result.

## Constraint to honor

Subagents must **not** load `browser-use:control-browser` (main-agent-only).
A reviewer that needs browser work hands the URL back to the main agent.

## Cross-references

- [`orchestrator-protocol.md`](../rules/orchestrator-protocol.md) — the runtime this overlay serves.
- [`orchestration-schemas.md`](orchestration-schemas.md) — the FINDING/SCORECARD contract reviewers return.
- [`agent-fleet.md`](agent-fleet.md) — which specialist fills which lens.
- [`model-routing.md`](../rules/model-routing.md) — role weights (single-model reality).
