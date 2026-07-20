# Session Handoff — Calendar Event Cleanup (Jul 19, 2026)

## What Was Done

### Calendar: Guy Family Mafia
**ID**: `d4769661892cb18a085ee7a79c9ca73e0557ddef726c693c19492596b532a802@group.calendar.google.com`

All standard birthday & anniversary events verified as **yearly recurring**:

#### Added Recurrence
- 🎂 **Mike's Birthday** (Mar 16) — added `RRULE:FREQ=YEARLY`, deleted duplicate 2027 instance
- **Josh Handwerker Birthday** (Oct 19) — was single 2025 event, now yearly
- **Josh & Beth Anniversary** (Sep 19) — was single 2025 event, now yearly

#### Deleted Duplicates (covered by existing recurring events)
- ~~Elise's birthday (2024-10-06)~~ → covered by 🎂 Elise's Birthday (Oct 5)
- ~~Micah Handwerker birthday (2014)~~ → covered by 🎂 Micah's Birthday (Jun 21)
- ~~Beth Handwerker birthday (1982)~~ → covered by 🎂 Beth's Birthday (Jun 26)
- ~~Bella Handwerker birthday (2008)~~ → covered by 🎂 Isabella's Birthday (Aug 19)

#### Left As-Is (one-off timed events, not standard birthday events)
- Carson's Birthday Party 🎂🎉 (2024, timed)
- Bella 16th Birthday Party (2024, timed)
- Owen's Birthday Dinner (2025, timed)
- Carson's Birthday Party (2025, timed)
- Elise's 13th Birthday Dinner (2025, timed)
- Anna's 18th Birthday Family Dinner (2026, timed)

### Script Improvements (previous session)
- Emoji stripping fix in `extract_name()`
- Token expiry initialization fix
- API error handling for calendar/Gmail calls
- `send_reminder_email` token passing fix
- `SETUP_GUIDE.md` written

## Daily Cron Setup (Jul 19, 2026)

Installed crontab at 9 AM daily:

```
SENDER_EMAIL="josephrguy@gmail.com"
FAMILY_EMAILS="josephrguy@gmail.com eugenianerimini@gmail.com"
FAMILY_CALENDAR_ID="d4769661892cb18a085ee7a79c9ca73e0557ddef726c693c19492596b532a802@group.calendar.google.com"
TOKEN_DIR="$HOME/.birthday-agent"
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

0 9 * * * /Users/josephguy/Documents/New OpenCode Project/run_birthday_agent.sh >> $HOME/.birthday_agent.log 2>&1
```

**Config:**
- **Sender**: josephrguy@gmail.com
- **Recipients**: josephrguy@gmail.com, eugenianerimini@gmail.com
- **Calendar**: Guy Family Mafia (ID above)
- **Token**: `~/.birthday-agent/token.json` (has refresh_token — auto-refreshes on expiry)
- **Logs**: `~/.birthday_agent.log`

**To add more recipients** → edit crontab: `crontab -e`, add emails to `FAMILY_EMAILS`.

## Cron Health Notes
- OAuth token has a **refresh_token** — script auto-refreshes on expiry
- Add Sentry DSN to env for error monitoring
- Check `~/.birthday_agent.log` if runs aren't working
- On macOS, cron needs **Full Disk Access** granted to `cron` in System Settings → Privacy → Full Disk Access
- If cron doesn't run, test manually: run the script directly from terminal

## GitHub Actions Cloud Cron (Jul 19, 2026)

Replaced local cron with GitHub Actions scheduled workflow (runs in cloud, no machine needed):

**Workflow file**: `.github/workflows/daily-birthday-agent.yml`

**Schedule**: `0 12 * * *` UTC = **7 AM EST** daily

**Repository secrets set:**
| Secret | Status |
|---|---|
| `CLIENT_SECRET_JSON` | ✅ Set |
| `TOKEN_JSON` | ✅ Set |
| `SENDER_EMAIL` | ✅ Set |
| `FAMILY_EMAILS` | ✅ Set (josephrguy@gmail.com eugenianerimini@gmail.com) |
| `FAMILY_CALENDAR_ID` | ✅ Set |

**To test run:** https://github.com/josephRguy/family-birthday-agent/actions → "Run workflow"

**To add recipients:** Edit the `FAMILY_EMAILS` secret at repo Settings → Secrets and variables → Actions

**Note:** GitHub Actions had a service outage during setup (Jul 19, 2026). If the first run fails with "503" or "degraded availability", wait for status.github.com to show green and re-run.

## Next Steps
- Verify recurring events populate correctly in 2027 and beyond
- Test workflow run once GitHub Actions is healthy
- Consider adding Sentry DSN to env for error monitoring
