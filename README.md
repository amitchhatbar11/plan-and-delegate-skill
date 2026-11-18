# plan-and-delegate

[![skills.sh](https://skills.sh/b/amitchhatbar11/plan-and-delegate-skill)](https://skills.sh/amitchhatbar11/plan-and-delegate-skill)

An agent skill for Claude Code: **plan with a strong model, execute with a cheaper one.**

When invoked, it detects your provider (Anthropic API, Amazon Bedrock, Google Vertex AI,
Microsoft Foundry, or an Anthropic-compatible gateway), asks which model to use for each
role, makes all design decisions in the main session, then hands a self-contained plan to
an executor subagent and, optionally, a reviewer subagent.

```
/plan-and-delegate <task>
  ├─ Step 0  install subagents (once) + detect provider/models
  ├─ Step 1  ask: executor model, reviewer model, keep planner?, save defaults?
  ├─ Step 2  PLANNER  (session model) investigates and writes the handoff
  ├─ Step 3  EXECUTOR (your pick) carries it out
  ├─ Step 4  REVIEWER (your pick, optional) checks the result
  └─ Step 5-6 planner fixes/re-delegates, reports models used per role
```

## Install

```bash
npx skills add amitchhatbar11/plan-and-delegate-skill
```

Or manually:

```bash
git clone https://github.com/amitchhatbar11/plan-and-delegate-skill
cp -r plan-and-delegate-skill/skills/plan-and-delegate ~/.claude/skills/
```

On first run the skill copies `executor`, `reviewer` and per-tier fallbacks
(`executor-haiku`, `executor-sonnet`, ...) into `~/.claude/agents/` (existing files are
never overwritten). Restart Claude Code once afterwards so the fallbacks load.

## Usage

```
/model opus
/plan-and-delegate add input validation to the signup form
```

You'll be asked which model executes and which reviews. Choose "save as defaults" to skip
the questions next time (stored in `~/.claude/plan-and-delegate.json`; delete it to be asked again).

## Pinning tiers to provider model IDs

Tiers (`opus` / `sonnet` / `haiku`) resolve to your provider's model IDs. Override in
`~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_DEFAULT_OPUS_MODEL":   "<your-opus-model-id>",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "<your-sonnet-model-id>",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL":  "<your-haiku-model-id>"
  }
}
```

## Executors on other providers (OpenCode Go, DeepSeek, OpenAI, Gemini...)

Claude Code subagents can only use the provider your Claude Code session runs on. To
execute with any other model, the skill hands the plan to an installed agent CLI:

| Backend | Setup | Example executor choice |
|---|---|---|
| [OpenCode](https://opencode.ai) | install, then `/connect` your provider (e.g. OpenCode Go) | `opencode:opencode-go/deepseek-v4.1-flash` |
| [Codex CLI](https://github.com/openai/codex) | install and log in | `codex:<model>` |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | install and log in | `gemini:<model>` |

Qwen Code and Aider are supported too. The skill lists every provider it can reach (Claude
Code tiers, installed CLIs with their connected providers and models, provider API keys in
the environment, local Ollama models) and offers them next to the Claude tiers. If the model
you want needs a CLI that isn't installed, it asks and installs it for you (or gives you the
command), then tells you how to log in to the provider yourself. It never handles your
API keys. See `skills/plan-and-delegate/references/backends.md`. External CLIs run with their own permissions (Codex `--full-auto`,
Gemini `--yolo`), so review the plan before delegating.

## Layout

```
skills/plan-and-delegate/
├── SKILL.md
├── agents/{executor,reviewer}.md
├── scripts/{detect_provider,install_agents,run_external}.sh
└── references/{handoff-template,backends}.md
```

## Tips

- A vague handoff costs more than it saves. If the executor keeps reporting BLOCKED, make
  the plan more explicit before moving up a tier.
- Haiku suits ~10-step mechanical chunks; Sonnet handles larger, trickier ones.
- The planner is always the current session model; a skill can't switch it mid-turn.

## License

MIT
