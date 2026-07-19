# Family Birthday Agent — Setup & Run Guide

This document covers everything from scratch: Google Cloud project creation, OAuth setup, environment config, testing, and scheduling.

---

## 1. Prerequisites

### 1.1 macOS Tools

```bash
brew install jq curl
```

The script runs with `/bin/zsh` (macOS default). Linux support requires minor edits (see §6).

### 1.2 Google Account

You need a Google account with access to:
- A **shared calendar** containing birthday/anniversary events
- **Gmail** for sending reminder emails

---

## 2. Google Cloud Project Setup

This is the most involved step — do it once.

### 2.1 Create Project

1. Go to https://console.cloud.google.com/projectcreate
2. Name it (e.g., "Family Birthday Agent") and click **Create**

### 2.2 Enable APIs

1. Go to **APIs & Services → Library**
2. Search for and enable **Google Calendar API**
3. Search for and enable **Gmail API**

### 2.3 Create OAuth Credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth Client ID**
3. Application type: **Desktop Application**
4. Name: "Birthday Agent Desktop"
5. Click **Create**
6. Click **Download JSON** — save to `~/.birthday-agent/client_secret.json`

```bash
mkdir -p ~/.birthday-agent
# Move the downloaded JSON here:
mv ~/Downloads/client_secret_*.json ~/.birthday-agent/client_secret.json
```

> **⚠️ Keep this file safe.** It's your OAuth secret. Never commit it.

---

## 3. Initial OAuth Authorization

You need a `token.json` with OAuth tokens. The script does NOT handle the initial authorization flow — you need to generate this separately.

### Option A: Quick Python Script (Recommended)

Save this as `oauth_setup.py` and run it:

```python
"""
One-time OAuth setup for the Family Birthday Agent.

Usage:
  pip install google-auth-oauthlib google-auth-httplib2
  python oauth_setup.py
"""

import os
import json
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/gmail.send",
]

CLIENT_SECRET = os.path.expanduser("~/.birthday-agent/client_secret.json")
TOKEN_OUT = os.path.expanduser("~/.birthday-agent/token.json")

flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET, SCOPES)
creds = flow.run_local_server(port=8080, open_browser=True)

# Add expiry as epoch for the shell script
token_data = json.loads(creds.to_json())
token_data["expiry"] = int(creds.expiry.timestamp())

os.makedirs(os.path.dirname(TOKEN_OUT), exist_ok=True)
with open(TOKEN_OUT, "w") as f:
    json.dump(token_data, f, indent=2)

print(f"✅ token.json saved to {TOKEN_OUT}")
print(f"   Expires at: {creds.expiry}")
print(f"   Scopes: {creds.scopes}")
```

Run:

```bash
pip install google-auth-oauthlib google-auth-httplib2
python oauth_setup.py
```

A browser will open asking you to authorize calendar.readonly + gmail.send. Approve it.

### Option B: Manual via Google OAuth Playground

1. Go to https://developers.google.com/oauthplayground
2. Click the gear icon → check **Use your own OAuth credentials**
3. Enter your Client ID and Client Secret from step 2.3
4. In scopes, enter:
   - `https://www.googleapis.com/auth/calendar.readonly`
   - `https://www.googleapis.com/auth/calendar.events`
   - `https://www.googleapis.com/auth/gmail.send`
5. Click **Authorize APIs** and complete the flow
6. Click **Exchange authorization code for tokens**
7. Copy the resulting JSON into `~/.birthday-agent/token.json`

### Option C: Use Existing Gmail Token

If you already have a `token.json` from another Google API tool that includes `gmail.send` scope, just symlink or copy it:

```bash
cp /path/to/existing/token.json ~/.birthday-agent/token.json
```

---

## 4. Find Your Shared Calendar ID

1. Open Google Calendar in a browser
2. Find the shared calendar in the left sidebar
3. Hover → click the three dots → **Settings and sharing**
4. Scroll to **Integrate calendar**
5. Copy the **Calendar ID** (looks like `abc123@group.calendar.google.com`)

---

## 5. Environment Variables

Add to your `~/.zshrc`:

```bash
# ── Family Birthday Agent ──
export SENDER_EMAIL="your-email@gmail.com"
export FAMILY_EMAILS="person1@gmail.com person2@gmail.com person3@gmail.com"
export FAMILY_CALENDAR_ID="abc123@group.calendar.google.com"
export TOKEN_DIR="$HOME/.birthday-agent"
```

Then reload:

```bash
source ~/.zshrc
```

### Variable Reference

| Variable | Required | Description |
|---|---|---|
| `SENDER_EMAIL` | Yes | Gmail address that sends the reminders |
| `FAMILY_EMAILS` | Yes | Space-separated list of recipient emails |
| `FAMILY_CALENDAR_ID` | Yes | The shared calendar to scan for events |
| `TOKEN_DIR` | No | Default: `~/.birthday-agent` — where token.json lives |
| `BIRTHDAY_AGENT_TODAY` | No | Override "today" date (for testing, format: YYYY-MM-DD) |

---

## 6. Test

```bash
cd /path/to/repo
chmod +x run_birthday_agent.sh

# Dry run — just check what it sees:
./run_birthday_agent.sh

# Force a specific date (to test a birthday or anniversary):
BIRTHDAY_AGENT_TODAY="2026-08-19" ./run_birthday_agent.sh
```

### Expected output (no events today):

```
Token expired. Refreshing...
No birthdays or anniversaries in the next 60 days.
Birthday agent run complete at ...
```

> The "Token expired" message appears on the **first run only** — subsequent runs within the token's 1-hour window will skip it.

### Expected output (event today):

```
Sent day-of haiku for Megan.
Created yearly recurring event for Megan birthday on primary calendar.
Birthday agent run complete at ...
```

---

## 7. Schedule Daily Cron

```bash
crontab -e
```

Add:

```cron
# Run daily at 9 AM
0 9 * * * /full/path/to/run_birthday_agent.sh >> $HOME/.birthday_agent.log 2>&1
```

Check the log to verify:

```bash
tail -f ~/.birthday_agent.log
```

---

## 8. How It Works

```
                        ┌───────────────────────┐
                        │  Google Calendar API   │
                        │  (shared calendar)     │
                        └───────┬───────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Check today's events  │
                    │  for birthday/anniv    │
                    └───────┬───────────────┘
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
       Events today              No events today
          │                           │
          │                     ┌──────┴──────┐
          │                     ▼             ▼
          │              Check 60-day    Nothing in
          │              lookahead       60 days → exit
          │                  │
          ▼                  ▼
   ┌────────────┐    ┌──────────────┐
   │ Send haiku │    │ 30d → poem  │
   │ or prose   │    │  7d → riddle│
   │ (day-of)   │    │  0d → haiku │
   └─────┬──────┘    └──────┬───────┘
         │                  │
         ▼                  ▼
   ┌──────────────────────────┐
   │ Create yearly recurring  │
   │ event on primary cal     │
   │ (if not already there)   │
   └──────────────────────────┘
```

### Reminder Schedule

| Event Type | 30 Days Out | 7 Days Out | Day Of |
|---|---|---|---|
| Birthday | Poem | Riddle | Haiku |
| Anniversary | — | Prose | Prose |

### Template System

The script has 250 unique templates (50 per type) stored in arrays:
- `POEMS_D` — birthday poems (30-day)
- `RIDDLES_D` — birthday riddles (7-day)
- `HAIKUS_D` — birthday haikus (day-of)
- `ANNIV_7D` — anniversary prose (7-day)
- `ANNIV_D` — anniversary prose (day-of)

Used templates are tracked in `~/.birthday_agent_state.json` and auto-reset each calendar year.

---

## 9. Calendar Event Naming

The script detects events whose summary contains "birthday" or "anniversary" (case-insensitive).

### Recommended event format:

```
🎂 Megan's Birthday (17th)
💍 Dave & Steph Anniversary
```

The script extracts the person name by stripping emoji, ordinals ("17th"), years ("2026"), the words "birthday"/"anniversary"/"party"/"celebration", and possessives ("'s").

### What gets created on your primary calendar:

- `Megan's Birthday` — recurring yearly, private visibility
- `Dave & Steph Anniversary` — recurring yearly, private visibility

---

## 10. Linux (Non-macOS)

The script uses macOS-specific `date` syntax. If running on Linux:

1. Replace `date -j -v+60d +%Y-%m-%d` with `date -d '+60 days' +%Y-%m-%d`
2. Replace `date -jf "%Y-%m-%d" "$event_date" "+%s"` with `date -d "$event_date" "+%s"`

A future version will auto-detect the platform.

---

## 11. Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `No token.json found` | OAuth not run | Run `python oauth_setup.py` |
| `Calendar API error: ...` | Invalid calendar ID or token expired | Verify `FAMILY_CALENDAR_ID` and token |
| `Gmail API error: ...` | Token lacks `gmail.send` scope | Re-run OAuth with gmail.send scope |
| No emails sent for today's event | `SENDER_EMAIL` not your Gmail | Must be the same as the OAuthed account |
| All templates show the same text | Template arrays exhausted (unlikely — 50 per type) | Delete `~/.birthday_agent_state.json` |
| No recurring events created on primary | Event already exists (by design — dedup check) | Check primary calendar for existing events |

### Reset Everything

```bash
# Clear OAuth (re-auth required)
rm -f ~/.birthday-agent/token.json

# Clear template state
rm -f ~/.birthday_agent_state.json

# Check logs
cat ~/.birthday_agent.log
```

---

## 12. Files Reference

| Path | Purpose |
|---|---|
| `run_birthday_agent.sh` | The agent script |
| `README.md` | Project overview |
| `SETUP_GUIDE.md` | This file |
| `~/.birthday-agent/client_secret.json` | OAuth client credentials (keep secret) |
| `~/.birthday-agent/token.json` | OAuth tokens (auto-refreshed) |
| `~/.birthday_agent_state.json` | Template usage tracker (auto-managed) |
| `~/.birthday_agent.log` | Cron output |
