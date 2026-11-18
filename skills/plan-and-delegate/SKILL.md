---
name: plan-and-delegate
description: >
  Plan with a strong model, execute with a cheaper one. Detects every provider and model the
  user can reach (Claude Code tiers, OpenCode, Codex, Gemini, Qwen, Aider, API keys, Ollama),
  asks once which model plays each role, makes all design decisions in the main session,
  hands self-contained plans to an executor and optional reviewer, uploads files from a
  known folder when a browser form needs them, and can send progress updates and ask for
  confirmations over Telegram. Use when the user invokes /plan-and-delegate, asks to "plan
  with X and execute with Y", or wants to save cost on a multi-step task.
---

# Plan and Delegate

You are the **planner**. You make every judgment call. Cheaper models do the work.

`SKILL_DIR` is the folder containing this file (e.g. `~/.claude/skills/plan-and-delegate`).
Preferences live in `~/.claude/plan-and-delegate.json`:

```json
{
  "executor": "<tier | backend:model>",
  "reviewer": "<tier | backend:model | none>",
  "notify": "telegram | manual",
  "upload_dir": "~/Documents/uploads"
}
```

## Decision policy: decide, don't ask

Make the obvious, positive and reversible decisions yourself, and keep going. Only ask
the user when one of these is true:

- The step **can't be undone or acts for the user outside this machine**: submitting a
  form or application, sending a message or email, paying, publishing or pushing,
  deleting data, changing an account. These always need a confirmation (see Confirmations).
- It needs **credentials or money** that weren't already approved.
- Two options are both reasonable and **pick materially different outcomes** that depend
  on the user's taste (not on best practice).

Everything else you decide: approach, file names, which of several matching files is the
newest/most relevant, defaults, retries, formatting, skipping clearly irrelevant items,
fixing small errors. Batch any questions you do need into one prompt. List the decisions
you made in the final report so the user can overrule them.

## Step 0: Setup and discovery

1. Install subagents (idempotent, never overwrites): `bash SKILL_DIR/scripts/install_agents.sh`.
   If it installed new ones, mention the per-tier fallbacks load after a Claude Code restart.
2. Discover everything available: `bash SKILL_DIR/scripts/detect_provider.sh`. It prints
   - **Claude Code subagents**: session provider and the model ID per tier (opus/sonnet/haiku).
   - **External agent CLIs** (OpenCode, Codex, Gemini, Qwen Code, Aider): installed or not,
     connected providers and models.
   - **Provider API keys** in the environment (names only), local Ollama models.
   - Saved preferences, Telegram status, and whether npm/python3/curl exist.

   Subagents can only use the session's provider; any other provider runs through an
   external CLI. Never say a model is unavailable without checking the external list.

## Step 1: One round of setup questions

Use saved preferences when present and the user didn't ask to change them (say which you
used). Skip any role the user already named in the request. Ask only what's left, in **one**
question-tool call:

1. **Executor**: every available Claude tier (labeled with its model ID) and the most
   relevant external models (e.g. `opencode: opencode-go/deepseek-v4.1-flash`).
   Recommend `haiku` for mechanical work, `sonnet` for skilled coding.
2. **Reviewer**: `No review` plus the same options. Recommend `sonnet`.
3. **Updates and confirmations**: `Telegram` (progress updates and Yes/No confirmations on
   your phone; needs a one-time setup) or `Manual in this chat` (recommended unless they
   want to step away).
4. **Save as defaults?** Yes (recommended) / No.

Planner = current session model. Don't ask about it; mention it, and that `/model <tier>`
before invoking changes it.

If the user picks a model nobody serves yet, do Step 1b. If they picked Telegram and
`detect_provider.sh` showed `telegram: not configured`, do Step 1c. Don't silently fall
back to something else.

Save the answers to the preferences file if they said yes.

### Step 1b: Install or connect a backend (only when needed)

Use `SKILL_DIR/references/backends.md` to find the CLI for the provider.

1. **CLI missing:** ask once: `Install <cli> for me (recommended)` showing the exact
   command / `I'll install it myself` / `Pick a different model`. If approved, run the
   official command and verify with `<cli> --version`. On failure (EACCES, no npm), apply
   the fix from `backends.md` and retry once.
2. **Provider not connected:** never ask for, type or store API keys. Give the user the
   exact login command for their own terminal (e.g. `opencode auth login` and pick
   OpenCode Go, or `codex login`) and wait.
3. Re-run `detect_provider.sh`, confirm the model is listed, continue.

### Step 1c: Telegram setup (only when chosen and not configured)

Follow `SKILL_DIR/references/telegram-setup.md`. In short, the user:
1. Creates a bot with @BotFather and copies the token.
2. Runs in **their own terminal**: `python3 SKILL_DIR/scripts/telegram.py setup`
   (it asks for the token privately, waits for them to message the bot, saves the chat ID
   to `~/.config/plan-and-delegate/telegram.json` with mode 600, and sends a test message).

You never see or handle the token. When they say done, check with
`python3 SKILL_DIR/scripts/telegram.py status`. If setup isn't possible now, use
`manual` for this run and say so.

## Step 2: Plan (your job)

- Investigate first: read files, run read-only commands.
- Decide everything under the decision policy.
- **Files to upload**: resolve them now (see File uploads) and put absolute paths in the handoff.
- Mark every irreversible step in the plan as `CONFIRM:` (see Confirmations).
- Write the handoff with `SKILL_DIR/references/handoff-template.md`. It must be
  self-contained. Chunks of ~10 steps (Haiku) or ~25 (Sonnet).
- Show a short plan summary, then continue without waiting unless something needs confirmation.
- If notify is telegram: `telegram.py send "Plan ready: <one line>. Starting."`

## Step 3: Delegate execution

**Claude Code subagent:** Task/Agent tool with `subagent_type: executor`,
`model: <EXECUTOR>`, `prompt: <handoff>`. If `model` is rejected, use
`subagent_type: executor-<EXECUTOR>`.

**External executor** (`backend:model`): write the handoff to `/tmp/pad-handoff-<n>.md`, run
`bash SKILL_DIR/scripts/run_external.sh <backend> <model> <file> <project dir>` with a long
timeout (in the background for long chunks). Exit 127 = CLI missing (Step 1b); auth/401
error = not connected (Step 1b.2). External CLIs run with their own auto-approve flags
(see `backends.md`), so tell the user once before the first run. For browser work and
anything irreversible, prefer a Claude Code subagent.

Executors never perform a `CONFIRM:` step. They stop just before it and report
`STATUS: NEEDS_CONFIRMATION` with what's ready. You get the confirmation, then delegate the
step (or do it yourself).

Independent chunks may run in parallel. With Telegram on, send a one-line update after
each chunk (`✓ chunk 2/4: filled form for Acme`) and on any failure.

## File uploads (browser forms and attachments)

When a step needs a file (resume, cover letter, ID, image, document), resolve it in this order:

1. A path the user gave in the request or conversation.
2. The `upload_dir` preference (default `~/Documents/uploads` if it exists).
3. The task's own folder (e.g. the project or a job agent's profile folder).

Run `bash SKILL_DIR/scripts/find_upload.sh <dir> <keywords...>` to list matches, newest first.
Pick the best match yourself: the right type for the field (PDF for resumes unless the
form wants DOCX), a name that matches the purpose or company, the newest version. Ask only
if two files fit equally well and differ in content. If nothing matches, ask once for a
path and offer to save its folder as `upload_dir`.

In the handoff, give the absolute path and exactly which field it goes in. The executor
uploads it with the browser tool's file-upload/set-input-files action on the file
`<input>` (never by typing the path or dragging), then checks the page shows the file name.
Never upload a file the plan didn't name.

## Confirmations

A `CONFIRM:` step needs a yes from the user before it runs.

- **notify = telegram:**
  `python3 SKILL_DIR/scripts/telegram.py confirm "<what will happen, with key details>" --timeout 1800`
  It sends Yes/No buttons and prints `YES`, `NO` or `TIMEOUT`. Only `YES` proceeds.
  `NO` skips that item and continues with the rest; `TIMEOUT` leaves it pending and lists it
  in the report. The user may also answer in chat; the first answer wins.
- **notify = manual:** ask in chat with the question tool.

Group confirmations when possible (e.g. one message listing 5 ready applications with
"Submit all?"), and include enough detail to decide without opening anything.

Claude Code's own tool-permission prompts appear only in the terminal; Telegram can't
answer them. For unattended runs, tell the user which tools to allow in their settings.

## Step 4: Review (skip if reviewer is none)

Subagent `reviewer` with `model: <REVIEWER>` (fallback `reviewer-<REVIEWER>`), or an
external reviewer via `run_external.sh` with a read-only review handoff. It returns
`VERDICT: PASS | ISSUES`.

## Step 5: Decide

- `BLOCKED` or `ISSUES`: decide yourself. Re-delegate a clearer chunk (max 2 retries) or fix it.
- Never push a design decision down to the executor.
- Verify before declaring done: diff, key test, or the page's confirmation.

## Step 6: Report

What changed, verification, pending confirmations, decisions you made on the user's
behalf, and:

| Role | Model | Notes |
|---|---|---|
| Planner | <session model> | |
| Executor | <model> | chunks, retries |
| Reviewer | <model or none> | verdict |

With Telegram on, also send a short summary: `telegram.py send "<summary>"`.
