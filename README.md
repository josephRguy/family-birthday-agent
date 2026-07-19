# 🎂 Family Birthday Agent

A daily cron agent that monitors a shared Google Calendar for birthdays and anniversaries, creates yearly recurring events on your primary calendar, and sends creative multi-stage email reminders (poems, riddles, haikus).

## How It Works

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│ Google      │────▶│ Birthday     │────▶│ Family Members  │
│ Calendar    │     │ Agent (zsh)  │     │ (email inbox)   │
│ (shared)    │     │              │     │                 │
└─────────────┘     │ • detects    │     │ 30 days out:    │
                    │ • creates    │     │   📜 poem       │
                    │ • reminds    │     │ 7 days out:     │
                    │              │     │   🧩 riddle     │
                    │              │     │ Day of:         │
                    │              │     │   🎊 haiku      │
                    └──────────────┘     └─────────────────┘
```

- Scans a shared calendar for all-day events containing "birthday" or "anniversary" (case-insensitive)
- Creates yearly recurring events on your primary calendar for tracking
- Sends email reminders at configurable intervals with creative content
- **250 unique templates** (50 per type) — poems, riddles, haikus, anniversary prose
- Tracks what's been sent via `~/.birthday_agent_state.json` (auto-resets each calendar year)

## Reminder Schedule

| Event Type | 30 Days Out | 7 Days Out | Day Of |
|------------|:-----------:|:----------:|:------:|
| 🎂 Birthday | Poem | Riddle | Haiku |
| 💍 Anniversary | — | Prose | Prose |

## Setup

### Prerequisites

- **macOS** with zsh (or Linux with bash — minor tweaks needed)
- `jq`, `curl`, `perl` — install via: `brew install jq curl perl`
- Google Cloud project with Calendar API and Gmail API enabled

### 1. Google Cloud OAuth

```bash
# Create OAuth credentials in Google Cloud Console:
# https://console.cloud.google.com/apis/credentials
# → Create Credentials → OAuth Client ID → Desktop Application
# Download the JSON and save to ~/.birthday-agent/client_secret.json
```

### 2. Authorize

Run the initial OAuth flow to get `token.json`:

```bash
# Follow the browser prompt, authorize calendar.readonly + gmail.send scopes
# Save the resulting token.json to ~/.birthday-agent/token.json
```

### 3. Export Environment Variables

Add these to your shell profile (`~/.zshrc`):

```bash
export SENDER_EMAIL="your-email@gmail.com"
export FAMILY_EMAILS="person1@gmail.com person2@gmail.com person3@gmail.com"
export FAMILY_CALENDAR_ID="your-shared-calendar-id@group.calendar.google.com"
# Optional: point to your OAuth token directory
export TOKEN_DIR="$HOME/.birthday-agent"
```

### 4. Test

```bash
chmod +x run_birthday_agent.sh
./run_birthday_agent.sh
```

### 5. Schedule Daily Cron

```bash
crontab -e
```

Add:

```cron
# Run daily at 9 AM
0 9 * * * /full/path/to/run_birthday_agent.sh >> $HOME/.birthday_agent.log 2>&1
```

### 6. (Optional) Refresh Calendar Data

The agent reads the shared calendar each run. To add events for the new year:

```bash
./run_birthday_agent.sh
```

## How to Find Your Shared Calendar ID

1. Open Google Calendar in a browser
2. Find the shared calendar in the left sidebar
3. Hover over the calendar name → click the three dots → **Settings and sharing**
4. Scroll to **Integrate calendar** → copy the **Calendar ID**

## Files

| Path | Purpose |
|---|---|
| `run_birthday_agent.sh` | The agent script (this is it) |
| `~/birthday-agent/token.json` | OAuth access/refresh tokens |
| `~/.birthday_agent_state.json` | Tracking state (auto-managed) |

## Template Counts

| Type | Count |
|------|:-----:|
| Birthday poems (30-day) | 50 |
| Birthday riddles (7-day) | 50 |
| Birthday haikus (day-of) | 50 |
| Anniversary prose (7-day) | 50 |
| Anniversary prose (day-of) | 50 |
| **Total** | **250** |

## License

MIT
