#!/usr/bin/env python3
"""Telegram updates and Yes/No confirmations for plan-and-delegate. Standard library only.

  telegram.py setup                  interactive, run by the user in their own terminal
  telegram.py status                 prints "telegram: configured" or "telegram: not configured"
  telegram.py send "<text>"          sends a message
  telegram.py confirm "<text>" [--timeout SECONDS]
                                     sends Yes/No buttons, prints YES, NO or TIMEOUT

Config: ~/.config/plan-and-delegate/telegram.json (mode 600) with bot_token and chat_id.
TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID environment variables override the file.
"""
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

CONFIG = os.path.expanduser("~/.config/plan-and-delegate/telegram.json")


def load():
    cfg = {}
    if os.path.exists(CONFIG):
        with open(CONFIG) as f:
            cfg = json.load(f)
    cfg["bot_token"] = os.environ.get("TELEGRAM_BOT_TOKEN", cfg.get("bot_token"))
    cfg["chat_id"] = os.environ.get("TELEGRAM_CHAT_ID", cfg.get("chat_id"))
    return cfg


def save(cfg):
    os.makedirs(os.path.dirname(CONFIG), mode=0o700, exist_ok=True)
    fd = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(cfg, f)


def api(token, method, params=None, timeout=40):
    data = urllib.parse.urlencode(
        {k: json.dumps(v) if isinstance(v, (dict, list)) else v for k, v in (params or {}).items()}
    ).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{token}/{method}", data=data)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = json.load(r)
    except urllib.error.HTTPError as e:
        body = json.load(e)
    if not body.get("ok"):
        raise SystemExit(f"telegram error: {body.get('description', 'unknown')}")
    return body["result"]


def latest_offset(token):
    upd = api(token, "getUpdates", {"timeout": 0})
    return upd[-1]["update_id"] + 1 if upd else 0


def require():
    cfg = load()
    if not cfg.get("bot_token") or not cfg.get("chat_id"):
        raise SystemExit("telegram: not configured (run: python3 telegram.py setup)")
    return cfg


def setup():
    cfg = load()
    token = cfg.get("bot_token") or getpass.getpass("Bot token from @BotFather (hidden): ").strip()
    me = api(token, "getMe")
    print(f"Bot: @{me['username']}")
    offset = latest_offset(token)
    print(f"Open Telegram and send any message (e.g. /start) to @{me['username']} ... waiting up to 3 minutes")
    deadline = time.time() + 180
    while time.time() < deadline:
        for u in api(token, "getUpdates", {"offset": offset, "timeout": 30}):
            offset = u["update_id"] + 1
            msg = u.get("message")
            if msg:
                cfg = {"bot_token": token, "chat_id": msg["chat"]["id"]}
                save(cfg)
                api(token, "sendMessage", {"chat_id": cfg["chat_id"], "text": "plan-and-delegate is connected. Updates and confirmations will arrive here."})
                print(f"Saved to {CONFIG}. Test message sent.")
                return
    raise SystemExit("No message received. Run setup again.")


def send(text):
    cfg = require()
    api(cfg["bot_token"], "sendMessage", {"chat_id": cfg["chat_id"], "text": text[:4000]})
    print("sent")


def confirm(text, timeout):
    cfg = require()
    token, chat = cfg["bot_token"], cfg["chat_id"]
    offset = latest_offset(token)
    tag = uuid.uuid4().hex[:8]
    msg = api(token, "sendMessage", {
        "chat_id": chat,
        "text": "Confirmation needed:\n\n" + text[:3800],
        "reply_markup": {"inline_keyboard": [[
            {"text": "✅ Yes", "callback_data": f"{tag}:yes"},
            {"text": "❌ No", "callback_data": f"{tag}:no"},
        ]]},
    })
    deadline = time.time() + timeout
    answer = None
    while answer is None and time.time() < deadline:
        wait = int(max(1, min(30, deadline - time.time())))
        for u in api(token, "getUpdates", {"offset": offset, "timeout": wait}, timeout=wait + 10):
            offset = u["update_id"] + 1
            cb = u.get("callback_query")
            if cb and str(cb["message"]["chat"]["id"]) == str(chat) and cb.get("data", "").startswith(tag + ":"):
                answer = cb["data"].split(":")[1].upper()
                api(token, "answerCallbackQuery", {"callback_query_id": cb["id"], "text": answer})
            m = u.get("message")
            if m and str(m["chat"]["id"]) == str(chat) and m.get("text", "").strip().lower() in ("yes", "y", "no", "n"):
                answer = "YES" if m["text"].strip().lower().startswith("y") else "NO"
    answer = answer or "TIMEOUT"
    try:
        api(token, "editMessageReplyMarkup", {"chat_id": chat, "message_id": msg["message_id"], "reply_markup": {"inline_keyboard": []}})
        api(token, "sendMessage", {"chat_id": chat, "text": f"Answer recorded: {answer}"})
    except SystemExit:
        pass
    print(answer)


def main(argv):
    if not argv:
        raise SystemExit(__doc__)
    cmd = argv[0]
    if cmd == "setup":
        setup()
    elif cmd == "status":
        cfg = load()
        print("telegram: configured" if cfg.get("bot_token") and cfg.get("chat_id") else "telegram: not configured")
    elif cmd == "send" and len(argv) > 1:
        send(argv[1])
    elif cmd == "confirm" and len(argv) > 1:
        t = int(argv[argv.index("--timeout") + 1]) if "--timeout" in argv else 1800
        confirm(argv[1], t)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
