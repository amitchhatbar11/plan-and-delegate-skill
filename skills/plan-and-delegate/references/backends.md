# External backends: which CLI serves which provider

Use this when the user picks a model that Claude Code subagents can't run.
Pick the first backend in the row that is already installed; otherwise suggest the first one.

| Provider / model family | Backends (preferred first) | Model ID format |
|---|---|---|
| OpenCode Go / OpenCode Zen (DeepSeek, Kimi, GLM, Qwen, MiniMax...) | opencode | `opencode-go/<id>`, `opencode/<id>` |
| OpenRouter (almost any model) | opencode, aider | `openrouter/<vendor>/<model>` |
| DeepSeek API | opencode, aider | `deepseek/<model>` |
| OpenAI (GPT, o-series) | codex, opencode, aider | codex: `<model>`; opencode: `openai/<model>` |
| Google Gemini | gemini, opencode, aider | gemini: `<model>`; opencode: `google/<model>` |
| Qwen (Alibaba / DashScope) | qwen, opencode | `<model>` |
| Groq, Mistral, xAI, Together, Fireworks, Ollama/local | opencode, aider | `<provider>/<model>` |
| Anthropic via another account/provider | opencode | `anthropic/<model>` |

## Install commands (official)

Always ask the user before running these. Prefer the npm one when `npm` exists.

| Backend | Install | Check | Connect a provider (user does this; never handle keys yourself) |
|---|---|---|---|
| opencode | `npm i -g opencode-ai` or `curl -fsSL https://opencode.ai/install \| bash` | `opencode --version` | run `opencode auth login` (or `/connect` in the TUI), then `opencode models` |
| codex | `npm i -g @openai/codex` | `codex --version` | `codex login` |
| gemini | `npm i -g @google/gemini-cli` | `gemini --version` | run `gemini` once and sign in, or set `GEMINI_API_KEY` |
| qwen | `npm i -g @qwen-code/qwen-code` | `qwen --version` | run `qwen` once and sign in, or set `DASHSCOPE_API_KEY` / OpenAI-compatible env |
| aider | `python3 -m pip install aider-install && aider-install` | `aider --version` | set the provider's API key env var (e.g. `OPENROUTER_API_KEY`) |

If `npm` is missing, point the user to https://nodejs.org (or their package manager) first.
Global npm installs may fail with EACCES; then suggest a user prefix
(`npm config set prefix ~/.local`) rather than `sudo`.

## Non-interactive run used by run_external.sh

| Backend | Command |
|---|---|
| opencode | `opencode run --model <provider/model> "<prompt>"` |
| codex | `codex exec --full-auto -m <model> "<prompt>"` |
| gemini | `gemini --yolo -m <model> -p "<prompt>"` |
| qwen | `qwen --yolo -m <model> -p "<prompt>"` |
| aider | `aider --yes-always --no-auto-commits --model <model> --message "<prompt>"` |
