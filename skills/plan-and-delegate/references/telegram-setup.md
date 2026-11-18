# Telegram setup (one time, about 2 minutes)

Telegram is optional. Pick it if you want progress updates and Yes/No confirmations on your
phone while the task runs. Otherwise choose "Manual in this chat".

1. In Telegram, open **@BotFather**, send `/newbot`, choose a name and a username ending in
   `bot`. BotFather replies with a **token** like `123456:ABC...`. Treat it like a password.
2. In your own terminal (not in the agent chat), run:

   ```bash
   python3 ~/.claude/skills/plan-and-delegate/scripts/telegram.py setup
   ```

   Paste the token when asked (input is hidden).
3. When it says "waiting", open your new bot in Telegram and send `/start`.
4. It saves `~/.config/plan-and-delegate/telegram.json` (readable only by you) and sends a
   test message. Tell the agent "done".

Check anytime: `python3 .../telegram.py status`. To disconnect, delete that JSON file
(and optionally `/deletebot` in BotFather).

## What arrives on Telegram

- One-line updates: plan ready, each chunk done or failed, final summary.
- Confirmations for steps that can't be undone (submitting, sending, paying, deleting),
  with ✅ Yes / ❌ No buttons. You can also reply `yes` or `no`. Unanswered requests time
  out (default 30 minutes) and are treated as not approved.

## Privacy

The token never passes through the agent: the setup script reads it from your terminal
and stores it locally. Messages contain task summaries, so avoid putting secrets in them.
