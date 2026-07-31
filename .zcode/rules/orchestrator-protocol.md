# Orchestrator Protocol: the review runtime

**The review-fix loop is a real runtime contract, expressed with the primitive every ZCode session has: the `Agent` subagent.** Skills fan out to forked reviewers, reduce their *structured* findings ([`orchestration-schemas.md`](../references/orchestration-schemas.md)) through a deterministic gate, judge with a hallucination guard, and loop until dry. What is *not* automatic is the **trigger**: nothing launches this loop on its own — the user (or a skill invocation) starts it. That boundary is deliberate (see "What is NOT automatic").

> **ZCode adaptation note.** The original Claude-Code template expressed this
> runtime with the `Task` tool and an explicit `context: fork` flag. ZCode's
> tool is named **`Agent`** (the harness auto-aliases `Task` ↔ `Agent`), and
> **fresh/forked context is the default subagent behavior** — there is no
> `context` parameter; every spawned agent gets its own isolated child session.
> So "fan-out in parallel" + "fresh context per reviewer" is achieved with
> plain parallel `Agent` tool calls. See the primitives below.

## The loop (the contract)

```
Skill invoked (with a RUN_CONFIG)
  │
  Step 1: IMPLEMENT / DRAFT
  │
  Step 2: VERIFY — compile, render, check outputs   (retry ≤ 2)
  │
  Step 3: FAN-OUT REVIEW — parallel forked reviewers, each returns FINDINGs
  │
  Step 4: REDUCE + JUDGE — stack scorecards; gate predicate → verdict;
  │        run the post-judge hallucination gate on judge-introduced CRITICALs
  │
  Step 5: FIX — apply critical → major → minor (with approval)
  │
  Step 6: SCORE — quality_score.py / hard-gate roll-up
  │
  └── converged?  (a round adds 0 new CRITICAL/MAJOR — see loop-until-dry)
        YES → present summary
        NO  → back to Step 3, in FRESH context
              (hard fallback cap reached → present with remaining issues)
```

## The runtime primitives

These four primitives are the runtime. Every fan-out skill is a composition of them; none should re-describe them in prose — they reference this section and [`orchestration-schemas.md`](../references/orchestration-schemas.md).

### 1. Fan-out

Spawn the reviewers **in parallel in a single message** — N `Agent` tool calls
in one assistant message. Each runs concurrently and returns its report to the
caller. **Fresh isolated context is the default**: every ZCode subagent gets
its own child session with no inheritance of the parent's history, so the main
thread stays clean and each reviewer gets the full context budget for its lens.
(There is no `context` parameter to set — fork is the only behavior.)

Which agent fills which lens is in [`agent-fleet.md`](../references/agent-fleet.md).

**Spawning a *named* specialist agent.** ZCode ships two built-in
`subagent_type` values — `general-purpose` (full tools) and `Explore`
(read-only). The template's 18 specialists (`editor`, `methods-referee`,
`claim-verifier`, …) are **not** registered as custom `subagent_type`s by
default; custom types in ZCode require shipping a plugin's `agents/` directory.
This fork uses **persona injection (Plan B)** instead — the default, lowest-
friction path:

- Spawn each specialist as `subagent_type: general-purpose`.
- In the `Agent` call's `prompt`, **prepend the specialist's full system
  prompt** (the body of its `.zcode/agents/<name>.md`, i.e. its persona,
  role, report format, and any "what would change my mind" / output-schema
  requirements). The agent's `tools:` field is honored by inlining an
  equivalent tool restriction in the prompt where needed; for read-only
  reviewers, `subagent_type: Explore` is a stricter choice that guarantees
  no writes.
- Give the prompt the artifact path + the lens rubric, exactly as the
  original `Task` call would have via `subagent_type`.

**Plan A (optional upgrade):** package `.zcode/agents/` as a local plugin
(`.zcode-plugin/plugin.json` with an `agents` component field) so the 18
specialists become real `subagent_type` values. Adopt this only if persona
injection proves insufficient; it is more setup for the same effect.

> Constraint: subagents must not load the `browser-use:control-browser` skill
> (main-agent-only). Reviewers that need browser work hand it back to the
> main agent.

### 2. Reduce (typed, not eyeballed)

Each reviewer returns `FINDING`s and a `SCORECARD` in the shared schema. The synthesizer **stacks typed objects** and applies the **gate predicate** — `CRITICAL>0 → BLOCK`, `MAJOR>0 → REVISE`, else `PASS`. The verdict is a deterministic function of the findings, not a re-judgment of the artifact.

### 3. Judge + hallucination gate

A synthesizer/editor may freely *downgrade* or *de-duplicate* lens findings, but any **CRITICAL it introduces that no lens raised** must survive the post-judge hallucination gate ([`orchestration-schemas.md` §4](../references/orchestration-schemas.md)): re-verify it in a fresh `Agent` call running the `claim-verifier` persona (persona injection — see Fan-out §1); if it can't be grounded, drop it to `[JUDGE-HALLUCINATED]` and recompute. This is what makes an autonomous review trustworthy next to a credibility-sensitive artifact.

### 4. Loop-until-dry

Replace bespoke "max 5 rounds" stopping logic with **convergence**: stop after **2 consecutive dry rounds** (a round that adds 0 new CRITICAL/MAJOR findings, deduped on `location`+`finding`). Guards:

- **Fallback cap** — `RUN_CONFIG.max_rounds` (default 5) bounds a non-converging loop.
- **Two-strikes** — the *same* finding surviving rounds N and N+2 is escalated to the user, not patched a third time ([`summary-parity.md`](summary-parity.md)).
- **Spend cap** — `RUN_CONFIG.spend_cap_tokens` (default ~500k) warns-and-asks; it is a spend ceiling, not a context limit (each re-audit is fresh).
- **Runaway backstop** — never exceed the harness's hard subagent cap; cost-pilot any ≥7× fan-out on one section before a full sweep.

### RUN_CONFIG: collect interactivity *before* launch

A forked subagent cannot stop to ask the user a question. So every interactive choice a fan-out needs — target journal, sampled dispositions, peeve budget, N referees, fresh-context flag, cross-artifact/novelty toggles — is gathered **before** the fleet spawns, echoed back as the **Pre-Flight Report**, and only then launched. Schema: [`orchestration-schemas.md` §5](../references/orchestration-schemas.md). An unresolved required field (e.g. an unknown journal) halts *before* launch, never mid-run. This is what lets `--peer`, `--variance`, and `editor` disambiguation keep their interactivity inside a no-mid-run-input runtime.

## Where the runtime is implemented

| Skill | Primitives | Notes |
|-------|-----------|-------|
| `/commit` | verify (Step 2), score (Step 6) | Halts on failure; `.githooks/pre-commit` enforces the same gates on every commit |
| `/seven-pass-review` | fan-out (7 lenses) → reduce → judge **+ hallucination gate** | Submission-ready / R&R papers |
| `/slide-excellence` | conditional fan-out → reduce | Spawns only lenses that can produce output; does not auto-fix |
| `/qa-quarto` | critic → fix → re-audit, **loop-until-dry** | Beamer↔Quarto parity; hard gates = CRITICAL roll-up |
| `/review-paper --adversarial` | critic → fix → re-audit, **loop-until-dry** | Manuscript review (same primitive as qa-quarto) |
| `/review-paper --peer` / `--variance` | RUN_CONFIG → editor → fan-out referees → editor synthesis **+ hallucination gate** | Cross-artifact pre-flight as Phase 0 |
| `/deep-audit` | mechanical checks → fan-out (4) → fix, **loop-until-dry** | Repo-wide consistency |
| `/create-lecture`, `/data-analysis` | Pre-Flight → draft → verify | Pre-Flight required |

## What is NOT automatic

- **No post-plan-approval trigger / no daemon.** Exiting plan mode does not launch a fix loop, and there is no background service that points the runtime at an artifact unattended. A multi-agent fix loop with no human in it, run against a submission, shared data, or a co-author's draft, is exactly the failure mode we refuse — the loop is always user/skill-initiated. **This is a documented non-goal, not a missing feature.**
- **No repo-wide orchestrator chaining.** Skills compose the primitives within their own scope; they do not invoke each other without an explicit call.
- **Quality gate enforcement.** `quality_score.py` runs inside `/commit`, **and** — once `./scripts/install-hooks.sh` is run — the `.githooks/pre-commit` hook runs the surface-sync + quality gates on every commit, so a direct `git commit` no longer bypasses the review (bypass is explicit: `SKIP_QUALITY_GATE=1` / `--no-verify`).

## "Just Do It" mode

When the user says "just do it" / "handle it" (within an already-invoked skill):

- Skip the final approval pause for the current skill; still run the full fan-out → reduce → judge → loop-until-dry; still present the summary.
- **Do NOT treat this phrase as commit authorization.** Commits require an explicit `/commit` or unambiguous request — see [`.zcode/skills/commit/SKILL.md`](../skills/commit/SKILL.md).

## Cross-references

- [`.zcode/references/orchestration-schemas.md`](../references/orchestration-schemas.md) — FINDING / SCORECARD / RUN_CONFIG / hallucination-gate contracts.
- [`.zcode/references/agent-fleet.md`](../references/agent-fleet.md) — the reviewer fleet + role weights (single-model: tiers are persona weights, not model pins).
- [`.zcode/rules/plan-first-workflow.md`](plan-first-workflow.md) — when to enter plan mode before invoking a skill.
- [`.zcode/rules/quality-gates.md`](quality-gates.md) — threshold definitions + the pre-commit hook.
- [`.zcode/rules/post-flight-verification.md`](post-flight-verification.md) — the forked-verifier mechanism the hallucination gate reuses.
- [`.zcode/rules/cross-artifact-review.md`](cross-artifact-review.md) — paper ↔ code dependency-graph pattern.
