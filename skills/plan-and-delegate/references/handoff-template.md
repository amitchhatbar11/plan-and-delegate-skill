# Handoff: <task title>

## Goal
<one or two sentences: what "done" means>

## Context the executor needs
- Repo/stack: ...
- Relevant files and what they do: ...
- Conventions to follow: ...

## Decisions already made (do not change)
- ...

## Files to upload (absolute paths, already verified to exist)
- `<field or page>` <- `/abs/path/to/file.pdf`
(Upload with the browser tool's file-upload / set-input-files action on the file input.
Check the page shows the file name. Never upload anything not listed here.)

## Steps
1. `<file or page>`: <exact change or action>
2. ...
3. CONFIRM: <irreversible action, e.g. click Submit>. Do NOT do it. Stop here and
   report NEEDS_CONFIRMATION with a summary of what is ready.

## Verification
- Run: `<command>`, expect: <result>

## Stop conditions
Stop before any step marked CONFIRM, and before any other action that submits, sends,
pays, publishes or deletes, even if it looks harmless.
Stop and report BLOCKED if a file, function or command doesn't match this
description, or if a step would need a decision that isn't listed above.
