<!-- CURRENT: GLM-5.2 (single model; ZCode builtin:zai-coding-plan provider) -->

# Current Model Versions (single source of truth)

> **Adapted for ZCode.** The original Claude-Code file tracked four Anthropic
> tiers (Fable / Opus / Sonnet / Haiku). This ZCode fork runs under a single
> configured model — there is no multi-tier routing in this environment.

**Last verified:** 2026-07-30

This file is the **one place** that names the configured model. Everything
else in the template should refer to it abstractly ("the configured model")
or point here. `scripts/check-model-versions.sh` is being adapted to this
single-model world (see stage 6); the `<!-- CURRENT: ... -->` marker above is
what it parses — keep it in sync with the table.

## The configured model

| Role | Model | Provider | Notes |
|------|-------|----------|-------|
| All agents + main session | **GLM-5.2** | `builtin:zai-coding-plan` | single model for this environment; resolves regardless of the `model:` alias (`opus`/`sonnet`/`haiku`) an agent declares |

### What this means in practice

- The `model: opus|sonnet|haiku` frontmatter on agents and commands is
  **parsed but inert** in this environment — it documents the original tier
  *intent* and preserves portability, but every run resolves to GLM-5.2.
- There is **no `effort:` axis** in ZCode; that field was removed from all
  skills and agents during adaptation.
- The original tier-based cost story (70/20/10 across Haiku/Sonnet/Opus) does
  not apply. Role weight (which agents are high-judgment vs mechanical) is now
  expressed via **persona strength** in each agent's `.md`, not via model
  selection. See [`model-routing.md`](../rules/model-routing.md).

## Prior generations (Claude Code, historical)

The original template (upstream `pedrohcgs/claude-code-my-workflow`) targeted
Anthropic tiers. These are mentioned only for historical/portability context;
they are **not** the models in use here:

- **Fable 5** / **Opus 4.8** / **Sonnet 4.6** / **Haiku 4.5** — the original
  four-tier fleet. The `model:` aliases on the agents map back to these if the
  repo is ever run under a multi-tier Anthropic-configured client.

## Update protocol

1. If the configured model changes, update the table **and** the
   `<!-- CURRENT: ... -->` marker above, plus the "Last verified" date.
2. Run `./scripts/check-model-versions.sh` (once adapted) and fix any
   current-state surface it flags.
3. Add a "Changed — model refresh" entry to `CHANGELOG.md`.
