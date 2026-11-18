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
   It prints the provider, session model, the model ID each tier (opus/sonnet/haiku) maps
   to, and saved preferences if any. Don't offer a tier marked `unavailable`.

## Step 1: Ask which model handles each role

If `detect_provider.sh` printed `saved_preferences:` and the user did not ask to change
them, use those and skip the questions (mention which ones you used).

If the user already named models in the request (e.g. "execute with haiku"), don't ask
about those roles again.

Otherwise ask with your question tool (AskUserQuestion), all in one call:

1. **Executor**: "Which model should carry out the plan?"
   Options: each available tier, labeled with its resolved model ID.
   Recommend `haiku` for mechanical/repetitive edits, `sonnet` for code needing real skill.
2. **Reviewer**: "Should another model review the result?"
   Options: `No review`, plus each available tier. Recommend `sonnet`.
3. **Planner**: "Planning runs on the current session model (<session_model>). Continue?"
   Options: `Yes, continue` / `Stop: I'll switch with /model first`.
   If the user stops, end the skill and tell them to run `/model <tier>` and re-invoke.
4. **Remember**: "Save these choices as defaults?" Options: `No` / `Yes`.
   If yes, write `~/.claude/plan-and-delegate.json`:
   `{"executor": "<tier>", "reviewer": "<tier|none>"}`

Record: `PLANNER=<session model>`, `EXECUTOR=<tier>`, `REVIEWER=<tier|none>`.

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

Independent chunks may be delegated in parallel; dependent chunks run in order.

## Step 4: Review (skip if REVIEWER is none)

Call the subagent tool with `subagent_type: reviewer` and `model: <REVIEWER>`
(fallback `reviewer-<REVIEWER>`). Give it the goal, the handoff, and the executor's report.
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
