# Outlook Mail, Calendar, Teams and OneDrive

**Ask Claude about your Outlook, Teams and OneDrive. It reads your Microsoft 365 email, calendar, Teams chats and OneDrive and SharePoint files from Claude Desktop on your Mac, and is read-only unless you turn on write tools.**

Version **0.18.0** · macOS · Claude Desktop extension (.mcpb)

- [Install: for people](#install-for-people)
- [Install: for AI agents](#install-for-ai-agents)
- [What you can do](#what-you-can-do)
- [Sign in and sign out](#sign-in-and-sign-out)
- [What it can and can't do](#what-it-can-and-cant-do)
- [Write tools](#write-tools)
- [Available tools](#available-tools)
- [Requirements](#requirements)
- [Sign-in and privacy](#sign-in-and-privacy)
- [Troubleshooting](#troubleshooting)
- [Update and remove](#update-and-remove)

---

## Install: for people

You need a Mac with Claude Desktop 2.7032.0 or later and a Microsoft 365 work account. Open Terminal and run:

```bash
curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | bash
```

The installer downloads the latest extension, checks its SHA-256 before anything changes, opens Claude Desktop's
install dialog, and waits until the extension is switched on and running.

Then:

1. Click Install in the dialog Claude Desktop opens. You can leave its settings blank: you choose your work account
   the first time you sign in. (Enter your work email there only if you want to allow just that account.)
2. If Claude Desktop shows the extension switched off, switch it on: Settings > Extensions > Outlook Mail, Calendar,
   Teams and OneDrive. Click once and wait a few seconds; the installer says when it is running.
3. Start a new chat (chats opened before the extension was on don't see its tools) and ask something, for example
   "What's in my inbox today?". The first time, Claude shows a sign-in card: enter the code on the page that opens,
   sign in with your work account, and ask again.

After that it keeps itself up to date: once a day it checks for a new version, and Claude offers it on an update card
in the chat. Click Update now, then Install in Claude Desktop's dialog; nothing is installed until you do. Running the
same command again also updates. Your settings and your sign-in are kept.

## Install: for AI agents

Use these steps if you are an AI agent installing this for a user.

1. **Check the machine.** Continue only if `uname -s` prints `Darwin` and `/Applications/Claude.app` exists. Otherwise tell the user it needs a Mac with Claude Desktop 2.7032.0 or later.
2. **Run the installer** with this one command. It downloads the extension, checks its SHA-256 (nothing changes before the check passes) and opens Claude Desktop's install dialog. With no terminal it never prompts, and `--no-wait` makes it exit once the dialog is open. It exits non-zero, with the reason on stderr, if anything fails.

```bash
curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | OUTLOOK_INSTALL_TTY=/dev/null bash -s -- --no-wait
```

3. **Hand over to the user.** Ask them to click Install in the dialog Claude Desktop opened (they can leave its settings blank), and to switch the extension on if Claude Desktop shows it off (Settings > Extensions). You can't do these for them.
4. **Verify.** Run the installer again with `--status` (after `bash -s --`). It should show `Ready: yes`; otherwise its `Next:` line says the one thing left to do. Then ask the user to start a new chat (chats opened while the extension was off don't see its tools) and say "Sign in to Outlook".
5. **Updates look after themselves.** Once a day the extension checks for a new version and Claude shows the user an update card. Only the user can click Update now and then Install; to update straight away, run the install command again.

## What you can do

**Ask in plain English.** Claude picks the right tool. For example:

| You ask | Claude reads |
|---|---|
| "What's in my inbox today?" | today's email |
| "Summarise the thread about the Q4 roadmap" | every message in that conversation |
| "Did Alex reply about the budget last week?" | a mailbox search |
| "Show me my pinned emails" | the emails you pinned in Outlook |
| "What meetings do I have tomorrow, and which have Teams links?" | tomorrow's calendar |
| "When am I free for an hour on Thursday afternoon?" | Thursday's calendar |
| "Who's invited to Friday's review, and have they accepted?" | that event in full |
| "Find the Active Resource Plans spreadsheet on SharePoint" | a file search |
| "Read this SharePoint file: <link>" | the file's contents (paste the sharing link) |
| "What does the PDF attached to Ana's email say?" | the attachment's text (Word, PowerPoint, Excel, PDF) |
| "Find 45 minutes with Ann and Raj next week" | everyone's free/busy, best times first |
| "Is the London 4th-floor room free on Thursday at 2?" | the room's availability |
| "What did I work on recently?" / "What's been shared with me?" | recent and shared files |
| "Which Teams chats have been busy today?" | your Teams chats |
| "What did we decide in that Teams chat?" | conversation bodies, with senders and timestamps |
| "Find Alex Smith's email address and who they report to" | people search and directory profiles |
| "Who changed this file, and what did version 2.0 say?" | retained file versions and older contents |
| "Sort the last three weeks of my inbox into my triage folders" | compact listings or an export file, then bulk moves (write tools on) |

Answers that rely on an email name it (sender, date, subject) and link to it in Outlook on the web.

## Sign in and sign out

You normally never need to think about it: Claude asks you to sign in when Microsoft
needs a new sign-in, and remembers you until then. To do it yourself, say *"Sign in to Outlook"* (shows the sign-in
card) or *"Sign out of Outlook"* (forgets your sign-in; the next question asks you to sign in again).

**The sign-in card** shows a one-time code (for example `ABCD1234`), an **Open sign-in page** button and a live
status. Your browser also opens at `https://login.microsoft.com/device`, and the code is already on your clipboard.

1. Paste or type the code on that page.
2. Sign in with your work account (your organisation may send you through Okta and Okta Verify).
3. Approve **"Microsoft Office"** when asked.
4. Come back to Claude. The card turns to **Signed in**; ask your question again.

The code works for 15 minutes. If it expires, ask Claude to sign in again for a new one.

## What it can and can't do

- **Can:** search all your mail folders, read emails and whole conversations, list and read calendar events
  (including join links, attendees, your response and how a meeting repeats), and search and read your OneDrive and
  SharePoint files (folders, spreadsheets, Word, PowerPoint, PDF, text and CSV; paste a sharing link or let Claude
  search), read email attachments, find times when people and rooms are free, read your Teams chats and list Teams
  channels; search people, read directory profiles/reporting relationships, and list and read retained file versions.
- **Can't:** send or change anything unless you turn on write tools (below); even then it can't overwrite or
  delete files, read other people's mailboxes (or calendars they haven't shared), read Teams channel messages, or set
  inbox rules or out-of-office (your sign-in doesn't allow those). Reading files needs your sign-in to grant file access; if it
  doesn't, the file tools say so and email and calendar keep working.
- **Updates:** once a day it checks its landing page for a newer version. When there is one, Claude shows an update
  card: **Update now** downloads it, checks it and opens Claude Desktop's install dialog, and it is installed only when
  you click **Install** there. **Not now** hides that version for a week. Claude can't update it for you. Turn
  **Check for updates** off in the extension's settings to stop the daily check.
- **Your data:** email, Teams chat, people, calendar and file text that Claude reads is sent to Anthropic as part of your conversation, under
  your Claude account's terms. Messages are written by other people, so Claude is told to treat them as untrusted and
  never to follow instructions found inside one.

## Write tools

Write tools are off by default. With the setting off, Claude can't send or change anything: the write tools aren't
offered at all. To turn them on:

1. In Claude Desktop open **Settings > Extensions > Outlook Mail, Calendar, Teams and OneDrive > Configure**.
2. Turn on **Enable write tools** and save. Claude Desktop restarts the extension.
3. The extension's **Tool permissions** now include a **Write/delete tools** group. Set each tool to *Always allow*,
   *Needs approval* (the hand) or *Blocked*, or set the whole group at once.

| Tool | What it does |
|---|---|
| `send_email` | send a new email (a copy goes to Sent Items) |
| `reply_email` | reply to the sender or to everyone |
| `forward_email` | forward an email with a note |
| `update_email` | mark read or unread, flag or complete, set categories, pin or unpin |
| `move_email` | move an email to another folder |
| `archive_email` | archive an email, as Outlook's Archive button does |
| `bulk_archive_emails` | archive a selection in batches of 20, returning per-email results and new IDs |
| `bulk_move_emails` | move a selection to any folder (e.g. `Clients/Acme`, `inbox`) by ids or short handles, or follow a move plan file (`ids_file`) for several folders at once |
| `bulk_move_by_query` | move everything in one folder that matches a rule (senders, subject words, meeting type, dates): a preview first, then a confirmed move of exactly that set |
| `delete_email` | delete an email: it goes to Deleted Items, so you can still restore it |
| `create_event` | create a meeting; attendees get an invitation (optionally with a Teams link) |
| `update_event` | change a meeting's title, time, place, text or attendees; attendees get the update |
| `respond_event` | accept, tentatively accept or decline an invitation, telling the organiser or quietly |
| `delete_event` | cancel a meeting you organised (attendees are told), or remove one from your calendar; one occurrence or the whole series |
| `create_draft`, `draft_reply`, `update_draft` | write an email, reply or forward into Drafts without sending, so you can check it in Outlook |
| `send_draft` | send a draft |
| `save_attachment` | save an email's attachment to OneDrive (exactly its bytes) |
| `create_mail_folder`, `rename_mail_folder` | make or rename a mail folder |
| `update_conversation` | mark, flag, categorise or move a whole conversation at once (changes first, then the move) |
| `set_focused_sender` | always put a sender's mail in Focused or Other, or remove that rule (says what it was) |
| `create_file`, `create_folder`, `copy_file` | create a text file or folder in OneDrive, or copy a file into it and get the copy back (never overwrites) |
| `save_file` | save any file from your Mac (any type, any size, e.g. `~/Downloads/deck.pptx`) to OneDrive; if the name is taken, the old file is kept as a backup copy, `<name> (backup <date> <time>)`, and nothing is deleted |
| `share_file` | share a file with named people, or, only when asked for (`org_wide`), make a link for anyone in your organisation (never a public link) |
| `unshare_file` | remove one share of a file (a person's access or a link); never your own access |
| `send_teams_message` | post to a Teams chat, channel, a colleague or a meeting's chat |
| `delete_teams_message` | delete a message you sent in a Teams chat; Teams shows it as deleted and offers Undo (not in channels) |

Sending, replying and forwarding can carry attachments: another email's attachment, a OneDrive/SharePoint file, or a
file on your Mac by its path (up to 25 MB; larger files can be saved to OneDrive with `save_file` and shared). The
first time Claude reads from your Downloads, Desktop or Documents folder, macOS asks whether Claude may.
`create_event` can also make repeating meetings and set a reminder, privacy and how the
time shows; `update_event` and `respond_event` can act on a whole series, and a decline can propose a new time.

For bulk archiving, collect the message IDs from `search_emails` or `list_emails` before calling
`bulk_archive_emails(message_ids=[...])`. Duplicate IDs are skipped. This uses the ordinary Archive folder, not the
separate Online Archive mailbox, so it does not free primary-mailbox storage. To move a selection to any other folder,
call `bulk_move_emails(message_ids=[...], folder="Clients/Acme")` with a well-known folder (`inbox`, `archive`,
`junkemail`...) or a path exactly as `list_folders` shows it; an unknown folder is refused before anything moves, and
moved emails are reported as `moved` rather than `archived`. Bulk moves into Deleted Items (or a folder in it) are
refused unless `allow_delete=true`, which Claude passes only when you ask to delete. Throttled requests are retried up
to three times per batch, respecting `Retry-After`, with at most 60 seconds of retry waiting per call. Results
distinguish `archived` or `moved`, `failed`, `unknown` and `not_attempted`; an email already in the folder counts as
moved. Check unknown outcomes in Outlook before retrying them; resume with only failed or not-attempted IDs rather
than replaying the whole selection. Every bulk move is written to the move log (see below).

### Triaging thousands of emails

For sorting weeks of mail into folders, the tools keep Claude's context small and never make it retype long ids:

- **Compact listings.** `list_emails`, `search_emails` and `list_pinned_emails` take `compact=true`: the field names
  once, then one short row per email (about 260 characters an email on real inbox mail, against about 850, so
  about a third of the size). Each email has a **handle** such as `m3f9a2` that every email tool accepts in place of its id,
  and `next_cursor` continues a listing. `list_emails` also takes `start`/`end` times to split a busy day.
  Previews lose "External:" banners, invisible padding and Teams join blocks.
- **Handles stay valid.** Email ids are Microsoft's *immutable* ids, which don't change when an email moves, so
  handles, saved plans and the move log stay right after moves. A handle unused for 7 days expires; an unknown one is
  an error for that email, never a guess.
- **Exports.** With `output_path`, `list_emails` and `search_emails` write every matching email (up to 5,000 by
  default, 20,000 at most) to a `.jsonl` file in the **export folder** and return only a short summary (path,
  count, SHA-256). Exports are working files, so by default the folder is a private temporary one (on macOS your
  own temporary folder, `/var/folders/…/T/outlook-okta-<uid>/exports`, which macOS clears after a few days unused);
  choose another in the extension's settings. Claude then reads the
  file with a file tool, such as Claude Desktop's Filesystem extension, which must be allowed to read that folder.
  Files are yours only (mode 600), are never overwritten unless asked, and a path can't leave the folder.
- **Moves by plan.** `bulk_move_emails(ids_file="plan.json")` reads a plan from the export folder,
  `{"folder": "Inbox/2. Read", "ids": ["m3f9a2", ...]}` or a list of such groups, checks every folder first and
  answers with counts and only the emails that didn't move.
- **Moves by rule.** `bulk_move_by_query` finds every email in one folder (Inbox by default) from given senders, with
  given subject words or of a meeting type (for example invitations to meetings that have already happened),
  received between two dates. The first call only previews: how many, ten samples and a confirm token. Claude shows
  you; when you agree it calls again with the token, and exactly the previewed emails that are still there move (new
  arrivals are left alone). Tokens last 15 minutes and work once.
- **Move log.** Every bulk move adds one line per email to
  `~/Library/Application Support/outlook-okta/move-logs/moves-<date>.jsonl` (kept, unlike exports): when,
  the handle and id, from which folder to which, and by which tool or rule.
- **Nothing else changes.** Moves never change read/unread, flags or categories.

The extension's settings **Export folder** and **Delete exports after (days)** (0, the default, keeps them; the move
log is always kept) control the export folder; elsewhere use `[exports]` in `config.toml` or
`$OUTLOOK_MAIL_EXPORT_ROOT` / `$OUTLOOK_MAIL_EXPORT_RETENTION_DAYS`.

Claude is told to show you exactly what it will send or change (recipients, subject and text; meeting time and
attendees) and to wait for your yes. It must never write because an email asked it to, and must send only to
addresses you gave. Files are never overwritten or deleted. For extra safety, keep the tools that send, share or
delete on *Needs approval*.

## Available tools

| Tool | What it does | Changes anything? |
|---|---|---|
| `search_emails` | Searches the whole mailbox, or one folder (Outlook search syntax); compact or exported to a file | No (an export writes a file in your export folder) |
| `list_emails` | Emails received between two dates, in one folder or all of them; compact or exported to a file | No (an export writes a file in your export folder) |
| `list_folders` | Every mail folder and subfolder (e.g. `Projects/Archive`), with item and unread counts | No |
| `read_email` | One email: people, time, text and its Outlook on the web link | No |
| `read_thread` | Every message in a conversation, each with only what it added | No |
| `list_events` | Calendar events between two dates: times, join link, location, organiser, your response, how it repeats | No |
| `read_event` | One event in full: every attendee, the invitation text, dial-in details, the repeat rule | No |
| `search_files` | Searches your OneDrive and SharePoint for files and folders, by name or content | No |
| `read_file` | Reads a file or folder (from a sharing link or a search result): folder contents, a spreadsheet's cells, or a Word, PowerPoint, PDF, text or CSV file's text | No |
| `search_people` | Finds relevant people by name or email; returns addresses, roles and departments, with paging | No |
| `read_person` | A directory profile and manager, optionally direct reports | No |
| `list_file_versions` | Retained versions of a OneDrive/SharePoint file: IDs, times, editors and sizes | No |
| `read_file_version` | An older version's text, including historical spreadsheet values | No |
| `list_file_permissions` | Who a file or folder is shared with: people, links, and access from a parent folder | No |
| `list_pinned_emails` | The emails you pinned in Outlook | No |
| `read_attachment` | One email attachment's text (Word, PowerPoint, Excel, PDF, text), or an attached email | No |
| `find_meeting_times` | Times when you and the people you name are all free | No |
| `get_availability` | Free/busy and working hours for colleagues or rooms | No |
| `list_rooms` | Meeting rooms and their addresses | No |
| `list_recent_files`, `list_shared_with_me` | Your recent files, and files shared with you | No |
| `list_chats`, `list_teams_channels` | Your Teams chats and channels (metadata) | No |
| `read_chat` | Bodies of one-to-one, group or meeting chats, with senders, timestamps and paging | No |
| Write tools (see above) | Only when **Enable write tools** is on | Yes |
| `sign_in` | Starts (or shows) the Microsoft sign-in and shows the sign-in card | Opens your browser |
| `sign_in_status` | Used only by the sign-in card to update itself; hidden from Claude | No |
| `sign_out` | Deletes your saved sign-in from the Keychain | Your sign-in only |
| `check_for_updates` | Checks the landing page for a newer version and shows the update card | No |
| `install_update`, `snooze_update` | Used only by the update card's Update now and Not now buttons; hidden from Claude | Opens Claude Desktop's install dialog |

### People search, file history and Teams conversations

People search uses Microsoft Search's **beta** people endpoint; profiles and reporting relationships use the stable
directory API. They depend on your sign-in granting people/directory access (`People.Read` / `User.Read.All`).
Search results can include personal contacts as well as colleagues; only results with `directory_user` can be
passed directly to `read_person`. Confirm the intended person's address before asking to send or invite them.

File history uses the existing file-read access. `list_file_versions` returns up to 200 versions and reports
truncation; history is limited by the site's retention settings. `read_file_version` reads older documents up to
25 MB, with the usual text-length limits. For current contents use `read_file`. File links open the current file,
so historical answers also identify the version and date. Reading a version does not restore or overwrite it.

For Teams conversations, call `list_chats` then `read_chat(target="<chat id>")`, or use
`read_chat(target="event:<event id>")` for a meeting chat. It returns up to 50 messages per page, starting with the
latest page and showing that page chronologically. If `has_more` is true, pass the returned `next_link` unchanged
with the same target to get older messages. Each body is capped at 20,000 characters, with a 50,000-character total
body-text budget per page; clipped bodies are labelled. Attachments are listed by name, not downloaded. Reading
needs `Chat.Read` or `Chat.ReadWrite`, works with write tools off and never creates a chat. Channel bodies aren't read.

## Requirements

| | |
|---|---|
| Operating system | macOS only (the sign-in is kept in the macOS Keychain). Tested on macOS 26, Apple silicon. |
| Claude Desktop | 2.7032.0 or later |
| Account | A Microsoft 365 work account and a web browser |
| Network at install | Claude Desktop downloads Python and the extension's locked dependencies once (about 120 MB on disk) |

You don't need to install Python, Node, a repository checkout or any configuration file.

## Sign-in and privacy

- The extension signs in as the pre-approved **Microsoft Office** app with your own account, using Microsoft's
  device-code sign-in: you enter a short code in your normal browser, so your organisation's usual sign-in (Okta,
  MFA) applies.
- After you sign in, Microsoft issues a refresh token. It is stored only in your **macOS login Keychain**, as the
  item `outlook-okta-refresh-token` (for your address if you set one, otherwise as `default`); never in a file or in
  the extension. Later questions refresh silently until Microsoft asks for a new sign-in (Conditional Access decides
  how often).
- With no work email set, the extension uses whichever work account you sign in with, and the sign-in card says
  which. If you set one in the extension's settings, signing in as any other account is refused.
- Only enter a code that Claude has just shown you, when you asked Claude something. Never enter a code someone
  sends you: that would sign them in as you.
- Microsoft issues the Office app's token with broad permissions (including sending mail). The extension never
  uses them, but anyone who could read your Keychain could. Keep your Mac locked.
- The installer checks the download's SHA-256 before anything changes, and never reads or prints your sign-in.
- Once a day the extension asks the landing page which version is the latest (one small download from GitHub Pages;
  nothing about you is sent). Its update card checks the new version's SHA-256 too, and only opens Claude Desktop's
  install dialog: nothing is installed until you click Install there. Turn **Check for updates** off in the
  extension's settings to stop the daily check.
- Report security problems privately to the maintainer, Jamie Mills (see SECURITY.md), not in an
  issue. Never include passwords, tokens, sign-in codes, Keychain contents, or email and calendar content in a report.

## Troubleshooting

| What you see | What to do |
|---|---|
| The installer says "Checksum mismatch — nothing was installed" | A new release can take up to about 10 minutes to reach every server. Wait, then run the install command again |
| The installer says Claude Desktop is missing or too old | Install or update Claude Desktop (2.7032.0 or later), open it once, then run the install command again |
| Claude says the extension isn't loaded, or has no Outlook tools | Switch it on (Settings > Extensions), then start a new chat: chats opened while it was off never see its tools |
| The installer says the extension is switched off, or was removed again | In Settings > Extensions, switch it on with one click and wait a few seconds; don't click Uninstall. If it was removed, run the install command again |
| `--status` says `Server: failed` | Run the install command again. If it keeps failing, the log it names (`~/Library/Logs/Claude/mcp-server-…`) says why |
| Claude says sign-in is needed | Expected the first time and when Microsoft wants a new sign-in: follow the card, then ask again |
| "You signed in as X, but this mailbox is set up for Y" | You set Y as the work email in the extension's settings, and your browser was signed in to another account. Sign out there or use a private window, then ask Claude to sign in again (or clear the work email setting) |
| The code expired | Ask Claude to sign in again for a new code |
| Claude Desktop refuses to install ("not compatible") | You need macOS and Claude Desktop 2.7032.0 or later |
| The extension shows as failed after install | It needs network access the first time. Check `~/Library/Logs/Claude/main.log` for `[UV Runtime]` lines, then reinstall |
| The tools appear twice | Remove the old `outlook-mail` entry from `claude_desktop_config.json` (quit Claude Desktop first) |

## Update and remove

- **Update:** when a new version is out, Claude shows an update card in the chat (at most once a day); click
  **Update now**, then **Install** in Claude Desktop's dialog, and start a new chat. **Not now** hides that version
  for a week. You can also ask *"Check for updates to Outlook"*, or run the install command again. Your settings and
  your sign-in are kept. To stop the daily check, turn **Check for updates** off in the extension's settings.
- **Remove:** say *"Sign out of Outlook"* first if you want the saved sign-in gone, then uninstall the extension
  in Settings > Extensions. (Or delete the `outlook-okta-refresh-token` item in Keychain Access.) The installer's
  download folder, `~/.outlook-mcp-server`, can then be deleted.

---

<sub>Generated from the project README for version 0.18.0. It is rebuilt automatically with each release.</sub>
