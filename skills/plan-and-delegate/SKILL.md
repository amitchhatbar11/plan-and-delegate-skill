---
name: plan-and-delegate
description: >
  Plan with a strong model, execute with a cheaper one. Asks the user which model to use
  for each role (planner, executor, reviewer) from the models available on their provider
  (Anthropic API, Bedrock, Vertex, or a gateway), makes every design decision in the main
  session, then hands a self-contained plan to an executor subagent and optionally a
  reviewer subagent. Use when the user invokes /plan-and-delegate or asks to "plan with X
  and execute with Y", or wants to save cost on a multi-step task.
---

# Plan and Delegate

You are the **planner**. You make every judgment call. Cheaper subagents do the work.

Paths below are relative to this skill's directory (`SKILL_DIR`): the folder containing
this file, e.g. `~/.claude/skills/plan-and-delegate` or `<project>/.claude/skills/plan-and-delegate`.

## Step 0: Setup and model discovery

1. Make sure the subagents exist (idempotent, never overwrites user edits):
   `bash SKILL_DIR/scripts/install_agents.sh`
   If it reports newly installed agents, tell the user that the per-tier fallback agents
   become available after Claude Code restarts; the per-call `model` override works now.
2. Discover provider and models:
   `bash SKILL_DIR/scripts/detect_provider.sh`
   It prints two kinds of executors:
   - **Claude Code subagents**: the session provider and the model ID each tier
     (opus/sonnet/haiku) maps to. Don't offer a tier marked `unavailable`.
   - **External agent CLIs** (OpenCode, Codex, Gemini) with the models they list. These
     reach other providers (e.g. OpenCode Go, OpenRouter, DeepSeek, OpenAI, Google).
   Plus saved preferences, if any.

   Subagents can only use the Claude Code session's provider. A model from any other
   provider runs through an external CLI. Never tell the user a model is unavailable
   without checking the external list.

## Step 1: Ask which model handles each role

If `detect_provider.sh` printed `saved_preferences:` and the user did not ask to change
them, use those and skip the questions (mention which ones you used).

If the user already named models in the request (e.g. "execute with haiku"), don't ask
about those roles again.

Otherwise ask with your question tool (AskUserQuestion), all in one call:

1. **Executor**: "Which model should carry out the plan?"
   Options: each available tier, labeled with its resolved model ID, **and** the external
   models found (label like `opencode: opencode-go/deepseek-v4.1-flash`; if many, offer
   the cheapest/most relevant few and let the user type any listed ID).
   Recommend `haiku` for mechanical/repetitive edits, `sonnet` for code needing real skill.
   If the user names a model that is in neither list, say which backend could serve it
   and how to set it up (e.g. install OpenCode, `/connect` the provider, check
   `opencode models`), then ask again. Don't silently fall back to a Claude model.
2. **Reviewer**: "Should another model review the result?"
   Options: `No review`, plus each available tier. Recommend `sonnet`.
3. **Planner**: "Planning runs on the current session model (<session_model>). Continue?"
   Options: `Yes, continue` / `Stop: I'll switch with /model first`.
   If the user stops, end the skill and tell them to run `/model <tier>` and re-invoke.
4. **Remember**: "Save these choices as defaults?" Options: `No` / `Yes`.
   If yes, write `~/.claude/plan-and-delegate.json`:
   `{"executor": "<tier or backend:model>", "reviewer": "<tier|backend:model|none>"}`

Record: `PLANNER=<session model>`, `EXECUTOR=<tier | backend:model>`, `REVIEWER=<same | none>`.

## Step 2: Plan (your job, in the main session)

- Investigate first: read relevant files, run read-only commands.
- Decide everything: approach, trade-offs, edge cases, names, file locations.
- Write the handoff using `SKILL_DIR/references/handoff-template.md`. It must be
  **self-contained**: the executor has no memory of this conversation.
- Split into chunks of ~10 steps max (Haiku) or ~25 (Sonnet). Larger tasks get several handoffs.
- Show the user a short summary of the plan before delegating.

## Step 3: Delegate execution

Call the subagent tool (Task/Agent) with:
- `subagent_type: executor`
- `model: <EXECUTOR>`
- `prompt:` the full handoff document

**Fallback:** if the tool rejects `model`, use `subagent_type: executor-<EXECUTOR>`
(fixed-model agents installed in Step 0). If neither exists yet, tell the user to restart
Claude Code, or do the work yourself if they prefer.

**External executor** (`EXECUTOR` is `backend:model`):
1. Write the handoff to a temp file, e.g. `/tmp/pad-handoff-<n>.md`.
2. Run `bash SKILL_DIR/scripts/run_external.sh <backend> <model> <file> <project dir>`
   with a generous timeout (10+ minutes); run it in the background for long chunks.
3. Treat its output like the executor's report. If it doesn't end in the
   `STATUS:` format, check the diff yourself to find out what was done.
The external CLI runs with its own permission settings (OpenCode uses its config; Codex
runs with `--full-auto`, Gemini with `--yolo`). Tell the user this before the first run.
For tasks that act outside the repo (browsing, submitting forms, sending anything),
prefer a Claude Code subagent, or require the handoff to stop before any irreversible step.

Independent chunks may be delegated in parallel; dependent chunks run in order.

## Step 4: Review (skip if REVIEWER is none)

Call the subagent tool with `subagent_type: reviewer` and `model: <REVIEWER>`
(fallback `reviewer-<REVIEWER>`), or for an external reviewer run `run_external.sh` with a
handoff that says: read-only review, reply `VERDICT: PASS | ISSUES`.
Give it the goal, the handoff, and the executor's report.
It returns `VERDICT: PASS` or a list of issues.

## Step 5: Decide

- Executor `BLOCKED` or reviewer `ISSUES`: **you** decide. Re-delegate a corrected,
  more explicit chunk (max 2 retries per chunk) or fix it directly.
- Never push a design decision down to the executor.
- Verify yourself before declaring done: look at the diff, run the key test.

## Step 6: Report

Tell the user what changed, verification results, open issues, and a table:

| Role | Model | Notes |
|---|---|---|
| Planner | <session model> | |
| Executor | <tier → model ID> | chunks, retries |
| Reviewer | <tier or none> | verdict |
