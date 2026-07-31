---
paths:
  - ".zcode/agents/**/*.md"
  - ".zcode/skills/**/SKILL.md"
---

# Agent Routing — the ZCode / single-model reality

> **Adapted from the original Claude Code `model-routing.md`.** That file
> described a 70/20/10 cost split across Anthropic tiers (Haiku / Sonnet /
> Opus). In this ZCode adaptation **there is one configured model**
> (`builtin:zai-coding-plan/GLM-5.2` — see `model-versions.md`); the
> `model:` frontmatter alias is parsed by ZCode but resolves to that single
> model regardless of the value. So the tier-based *cost* story does not
> apply here. What **does** carry over is the *role weight* taxonomy below:
> which agents are high-judgment (and so deserve the most careful prompting
> and the most independent verification), and which are mechanical.

## The single-model fact

- `model: opus|sonnet|haiku` in agent `.md` frontmatter is **retained for
  compatibility** (and future portability back to a multi-tier setup), but in
  this environment every agent runs on the one configured model. Do not treat
  the value as a live cost/quality lever.
- ZCode has **no `effort:` axis** (that field was removed from all skills and
  agents during adaptation). The original "effort is the first cost lever"
> guidance is therefore inactive here.
- Because there is no cheap tier, the real cost control is **how many agents
  you fan out** and **how much work each one does**, not which model runs.

## What still matters: role weight (persona, not tier)

The original tier assignment is repurposed as a **role-weight** taxonomy.
High-judgment roles get stronger system prompts and are the ones that matter
most for the hallucination gate / two-strikes guards; mechanical roles are
bounded, read-mostly, and cheap to re-run. Use this when deciding how much
prompting rigor and how much independent verification an agent earns.

### High-judgment roles (careful persona, gate-protected)

These protect the artifact from expensive mistakes (a desk-reject, a
hallucinated citation, a biased estimator). Give them the strongest, most
specific persona in their `.md`, and never shortcut their verification:

- `editor` — desk review, referee selection, editorial synthesis.
- `domain-referee`, `methods-referee` — substance + methodology referees.
- `claim-verifier` — fresh-context CoVe verifier (citations, numbers, novelty).
- `quarto-critic` — adversarial Beamer↔Quarto parity critic.
- `tikz-reviewer` — measurement-based TikZ collision/aesthetic audit.
- `domain-reviewer`, `sim-reviewer`, `verifier` — field substance / Monte Carlo / commit gate.

### Review / critique roles (read-only, bounded)

- `r-reviewer`, `r-package-reviewer`, `slide-auditor`, `proofreader`,
  `pedagogy-reviewer`, `humanize-auditor`.

### Mechanical / voting roles (re-runnable, cheap to redo)

- `quarto-fixer`, `beamer-translator` (the only fleet members that **write**),
  `promote-memory-council`.

## The anti-patterns that survive the single-model collapse

Two of the original anti-patterns still hold, for *diversity* reasons rather
than cost reasons:

1. **Don't weaken a high-judgment agent's persona to "save effort."** With no
   cheap tier, the only way an agent gets worse is a vaguer prompt. Keep the
   verifier/referee/editor system prompts sharp.
2. **Challenger ≠ auditor must differ in *something*.** The original rule said
   a challenger must run on a different *tier* than the auditor to avoid
   correlated blind spots. With one tier, that diversity has to come from
   **different personas / different prompt framings / fresh forked context**
   instead of a different model. The fresh-context fork (ZCode's default
   subagent behavior) is the load-bearing piece — it is what `claim-verifier`
   and the post-judge hallucination gate rely on. Keep it.

## How `/commit` uses this rule

`/commit`'s pre-commit verifier runs on the single configured model. There is
no cheaper tier to route it to, so the lever is **scope**: the verifier only
checks the changed files' compile/render, not a full repo sweep.

## Cross-references

- [`.zcode/rules/cross-artifact-review.md`](cross-artifact-review.md) — paper ↔ code dependency graph.
- [`.zcode/rules/post-flight-verification.md`](post-flight-verification.md) — the CoVe / forked-verifier mechanism (diversity now comes from fresh context, not a different tier).
- [`.zcode/references/model-versions.md`](../references/model-versions.md) — the single configured model.
- [`.zcode/rules/orchestrator-protocol.md`](orchestrator-protocol.md) — fan-out uses ZCode's `Agent` tool; fresh context is the default.
