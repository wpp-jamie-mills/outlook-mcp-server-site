#!/bin/bash
# AUTO-GENERATED: Published to GitHub Pages by CI on each tagged release.
# Do not edit the published copy — edit install.sh in the outlook-okta repository instead.
#
# Installs the latest Outlook Mail, Calendar, Teams and OneDrive extension (.mcpb) into Claude Desktop (macOS).
#   curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | bash
# For an AI agent or a script (no terminal: it never prompts, and doesn't wait for the install dialog):
#   curl -fsSL <same url> | OUTLOOK_INSTALL_TTY=/dev/null bash -s -- --no-wait
# When the organisation blocks the extension, the same release as a Claude Desktop mcpServers entry (needs uv):
#   curl -fsSL <same url> | bash -s -- --entry
#
# Environment overrides (mainly for tests):
#   OUTLOOK_MCP_HOME           download folder (--dir wins; default ~/.outlook-mcp-server)
#   OUTLOOK_INSTALL_BASE       base URL for the download files (default: the GitHub Pages site)
#   OUTLOOK_INSTALL_TTY        where questions are read from (default /dev/tty; /dev/null = no terminal)
#   OUTLOOK_CLAUDE_APP         path to Claude.app (default /Applications/Claude.app)
#   OUTLOOK_INSTALL_NO_OPEN    1 = don't open Claude Desktop (its install dialog, or the app for --entry); just say
#                              what would happen
#   OUTLOOK_INSTALL_WAIT_SECS  how long to wait for the extension (or the entry) to be installed and running
#                              (default 600; 0 with --no-wait or OUTLOOK_INSTALL_NO_OPEN=1)
#   OUTLOOK_INSTALL_SETTLE_SECS  after that, how long to wait before checking it is still there (default 5)
#   OUTLOOK_INSTALL_UV         where to look for uv, as a colon-separated list (default: uv on PATH, then
#                              /opt/homebrew/bin/uv, /usr/local/bin/uv, ~/.local/bin/uv); empty = nowhere
#   OUTLOOK_INSTALL_BREW       Homebrew's brew for installing uv (default: brew on PATH or in /opt/homebrew or
#                              /usr/local); empty = no Homebrew
#   OUTLOOK_INSTALL_UV_BASE    where uv's release tarballs are downloaded from (default: its GitHub release)
#   OUTLOOK_INSTALL_UV_SHA256  the tarball's expected SHA-256 instead of the pinned one (for testing)
#   OUTLOOK_MAIL_DATA_DIR      the server's data folder, as the server reads it (default
#                              ~/Library/Application Support/outlook-okta); --entry installs into its server folder
set -euo pipefail

# Default download base (the prerelease copy is rewritten to point at /rc). Exactly one such line.
SITE_BASE_DEFAULT="https://wpp-jamie-mills.github.io/outlook-mcp-server-site"
# The stable site, also from the prerelease copy (where --entry is refused: the entry installs stable releases only).
SITE_BASE_STABLE="${SITE_BASE_DEFAULT%/rc}"

APP_TITLE="Outlook Mail, Calendar, Teams and OneDrive"
# The oldest Claude Desktop the extension supports (manifest.json compatibility.claude_desktop).
MIN_CLAUDE_VERSION="2.7032.0"
# The Keychain item holding the saved sign-in (outlook_okta/auth.py KEYCHAIN_SERVICE). Only its presence is checked.
KEYCHAIN_SERVICE="outlook-okta-refresh-token"
# --entry: the mcpServers entry's name in claude_desktop_config.json (Claude Desktop names its log after it), and
# the command `outlook-mail install-release` writes in <data folder>/server (outlook_okta/managed.py LAUNCHER).
ENTRY_NAME="outlook-m365"
LAUNCHER_NAME="outlook-m365-mcp"
# The entry runs with uv. When it is missing and the owner agrees (or --install-uv), the installer installs it: with
# Homebrew when there is one, else this uv release from GitHub, checked against its published SHA-256 (pinned here),
# into ~/.local/bin. The same version as CI's (.github/workflows/mcpb.yml setup-uv).
UV_VERSION="0.12.18"
UV_SHA256_AARCH64="cf40e0c6a202190ccd9e0406dcfdd5b2d6668a9a5c779b17948963df32aafe5b"
UV_SHA256_X86_64="2e4108f5395397c8bc5d43bf83d3bdbb2d0e92b90d0efa607756be704905fa33"

# Colour only on a terminal, so agent and CI logs stay plain.
if [[ -t 1 && -t 2 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# printf, not echo -e, so backslashes in paths are shown as typed.
print_error() { printf '%b✗ %s%b\n' "$RED" "$1" "$NC" >&2; }
print_success() { printf '%b✓ %s%b\n' "$GREEN" "$1" "$NC"; }
print_warning() { printf '%b⚠ %s%b\n' "$YELLOW" "$1" "$NC"; }
print_step() { printf '%b→ %s%b\n' "$BLUE" "$1" "$NC"; }
die() {
  print_error "$1"
  exit 1
}

OUTLOOK_TEMP_DIR=""
cleanup_temp() {
  if [[ -n "$OUTLOOK_TEMP_DIR" && -d "$OUTLOOK_TEMP_DIR" ]]; then rm -rf "$OUTLOOK_TEMP_DIR"; fi
}

usage() {
  cat <<'EOF'
Outlook Mail, Calendar, Teams and OneDrive installer (macOS, Claude Desktop)

Usage:
  curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | bash
  curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | bash -s -- --status
  curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | bash -s -- --entry

It downloads the latest extension (.mcpb), checks its SHA-256 before anything changes, opens Claude Desktop's
install dialog, and waits until the extension is installed, switched on and running. Click Install there. Running
it again updates the extension and keeps your settings and your sign-in.

Options:
  --dir <path>   Folder for the downloaded extension (default: ~/.outlook-mcp-server).
  --status       Print what is installed (download, Claude Desktop, the extension and whether it is switched
                 on or blocked by your organisation, write tools, the mcpServers entry, whether the server is
                 running, whether a sign-in is saved), the latest version, and the one thing left to do
                 ("Next:") or "Ready:". Never prints the sign-in or the email address.
  --entry        For when your organisation blocks the extension: install the same release as a Claude
                 Desktop mcpServers entry instead. It needs uv: if uv is missing, the installer asks whether to
                 install it (see --install-uv). Installs the release in
                 ~/Library/Application Support/outlook-okta/server, then adds an "outlook-m365" entry to
                 Claude Desktop's claude_desktop_config.json (asks first; with no terminal, add --yes). It keeps
                 a backup of that file and everything else in it. Then quit and reopen Claude Desktop; the
                 installer waits until the entry is running. Running it again updates the release.
  --install-uv   With --entry: if uv is missing, install it without asking (the user's go-ahead, for agents and
                 scripts): with Homebrew if there is one (brew install uv), otherwise uv's own release from
                 GitHub, checked against a SHA-256 pinned in this installer, into ~/.local/bin. Shell profiles
                 aren't changed. Does nothing when uv is already installed.
  --no-wait      Open Claude Desktop's install dialog and exit without waiting for you to click Install
                 (same as OUTLOOK_INSTALL_WAIT_SECS=0); with --entry, exit without waiting for Claude Desktop
                 to start the entry. Check later with --status: exit 0 means the installer finished its
                 steps, not that Claude Desktop installed the extension.
  --uninstall    Remove the download folder (asks first; with no terminal, add --yes). The extension itself
                 is removed in Claude Desktop: Settings > Extensions. With --entry: remove the outlook-m365
                 entry from claude_desktop_config.json (keeping a backup) and the installed release instead.
  --yes          Answer yes to removing a folder or the entry, and to adding or changing the entry in
                 claude_desktop_config.json. Installing uv is a separate yes: --install-uv.
  --help         Show this help.

Environment:
  OUTLOOK_MCP_HOME
      Same as --dir (--dir wins).
  OUTLOOK_INSTALL_TTY
      Where questions are read from; /dev/null means no terminal (every answer is no).
  OUTLOOK_INSTALL_BASE
      Where the release files are downloaded from (default: the project site). For testing.
  OUTLOOK_INSTALL_UV
      Where --entry looks for uv, colon-separated (default: uv on PATH, then /opt/homebrew/bin/uv,
      /usr/local/bin/uv, ~/.local/bin/uv).
  OUTLOOK_MAIL_DATA_DIR
      The server's data folder (default ~/Library/Application Support/outlook-okta); --entry installs into its
      server folder.
EOF
}

# Physical path of $1 with symlinks resolved in the part that already exists, so the restricted-folder
# checks can't be dodged with symlinks, double slashes or a different spelling.
canonical_path() {
  local path="$1" rest="" dir
  while [[ ! -d "$path" ]]; do
    rest="/${path##*/}$rest"
    path="${path%/*}"
    [[ -n "$path" ]] || path="/"
  done
  dir="$(cd -P "$path" 2>/dev/null && pwd -P)" || return 1
  [[ "$dir" != "/" ]] || dir=""
  printf '%s%s\n' "$dir" "$rest"
}

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Questions are read from the terminal, not stdin (stdin is the script itself under curl | bash).
can_answer() { [[ "$OUTLOOK_INSTALL_TTY_PATH" != /dev/null ]] && { : <"$OUTLOOK_INSTALL_TTY_PATH"; } 2>/dev/null; }

ask_yes_no() {
  local reply=""
  can_answer || return 1
  printf '%s [y/N] ' "$1" >"$OUTLOOK_INSTALL_TTY_PATH"
  read -r reply <"$OUTLOOK_INSTALL_TTY_PATH" || return 1
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

sha256_of() {
  # Hash from stdin: shasum escapes file names containing backslashes and prefixes the hash with "\".
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | awk '{ print $1 }'
  else
    shasum -a 256 <"$1" | awk '{ print $1 }'
  fi
}

# Succeeds when dotted version $1 >= $2 (numeric per part; missing parts count as 0).
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, "."); if (m > n) n = m
    for (i = 1; i <= n; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 }
    exit 0
  }'
}

# Succeeds when release $1 is older than $2. X.Y.Z compares part by part; a pre-release (X.Y.Z-rc.N) is older than
# its X.Y.Z, and two pre-releases of one X.Y.Z compare as text.
version_older() {
  local a="${1%%-*}" b="${2%%-*}"
  [[ "$1" != "$2" ]] || return 1
  if [[ "$a" != "$b" ]]; then
    ! version_ge "$a" "$b"
  elif [[ "$1" == *-* && "$2" == *-* ]]; then
    [[ "$1" < "$2" ]]
  else
    [[ "$1" == *-* ]]
  fi
}

# Claude Desktop's version (CFBundleShortVersionString), or nothing if it can't be read.
claude_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null || true
}

# What Claude Desktop lists for this extension, read with JavaScript for Automation (no jq, node or python):
#   "<version> <enabled|disabled|blocked|unknown> <email-set|email-missing|unknown> <writes-on|writes-off|unknown>",
#   or "none" when it isn't installed. blocked: the organisation hasn't approved the extension, so Claude Desktop
#   keeps it switched off (orgBlockedReason, "Extension is not approved for your organization", seen 2026-11-15).
#   $1 = Claude Desktop's Application Support folder. Never prints the email address.
claude_extension_state() {
  osascript -l JavaScript - "$1" <<'JXA' 2>/dev/null || echo none
ObjC.import("Foundation");
function readJson(path) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(
    $(path).stringByResolvingSymlinksInPath,
    $.NSUTF8StringEncoding,
    null,
  );
  if (text.isNil()) return null;
  try {
    return JSON.parse(text.js);
  } catch (e) {
    return null;
  }
}
function run(argv) {
  const all = (readJson(argv[0] + "/extensions-installations.json") || {}).extensions || {};
  const key = Object.keys(all).find((k) => /^[A-Za-z0-9._-]+\.outlook-mail$/.test(k));
  if (!key || !all[key] || !/^[0-9A-Za-z.+-]{1,40}$/.test(String(all[key].version || ""))) return "none";
  const settings = readJson(argv[0] + "/Claude Extensions Settings/" + key + ".json");
  let enabled = "unknown";
  let email = "unknown";
  let writes = "unknown";
  if (settings) {
    if (settings.isEnabled === true) enabled = "enabled";
    if (settings.isEnabled === false) enabled = "disabled";
    const blocked = settings.orgBlockedReason;
    if (typeof blocked === "string" && blocked.trim()) enabled = "blocked";
    const config = settings.userConfig || {};
    const value = config.user_email;
    email = typeof value === "string" && value.trim() ? "email-set" : "email-missing";
    const w = config.enable_write_tools;
    writes = w === true || w === "true" ? "writes-on" : "writes-off";
  }
  return String(all[key].version) + " " + enabled + " " + email + " " + writes;
}
JXA
}

# Is Claude Desktop open?
claude_running() { pgrep -x Claude >/dev/null 2>&1; }

# What Claude Desktop's own log for this extension says about its server, from the last start on:
#   "<none|starting|running|stopped|failed> <UTC time> <error text, for failed>". $1 = the log file.
# A reply logged after a shutdown (a late answer from a server being stopped) doesn't count as running. Reads from
# the last start in the whole log: Claude Desktop logs every message, so a busy server's start can be thousands of
# lines back.
server_state() {
  local from
  [[ -f "$1" && -r "$1" ]] || {
    echo none
    return 0
  }
  from="$(grep -n -F 'Initializing server...' "$1" 2>/dev/null | tail -n 1 | cut -d: -f1)"
  [[ -n "$from" ]] || {
    echo none
    return 0
  }
  tail -n "+$from" "$1" | awk '
    match($0, /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9:.]*Z /) {
      ts = substr($0, 1, RLENGTH - 2)
      if (index($0, "Initializing server...")) { state = "starting"; since = ts; err = ""; next }
      if (state == "") next
      if (index($0, "transport closed unexpectedly")) { state = "failed"; since = ts; next }
      if (index($0, "] [error] ")) {
        e = $0
        sub(/^.*\] \[error\] /, "", e)
        if (err == "") err = substr(e, 1, 140)
        if (index(e, "Server disconnected")) { state = "failed"; since = ts }
        next
      }
      if (state == "failed") next
      if (index($0, "Shutting down server") || index($0, "shutting down server")) { state = "stopped"; since = ts; next }
      if (state == "starting" && index($0, "Message from server:")) { state = "running"; since = ts }
    }
    END { if (state == "") print "none"; else print state, since, err }'
}

# A UTC time from the log ("2026-10-15T13:58:54.739") as local time: "14:58" today, "15 Oct 14:58" otherwise.
local_time() {
  local epoch
  epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "${1%%.*}" '+%s' 2>/dev/null)" || {
    printf '%s UTC\n' "${1%%.*}"
    return 0
  }
  if [[ "$(date -r "$epoch" '+%Y-%m-%d')" == "$(date '+%Y-%m-%d')" ]]; then
    date -r "$epoch" '+%H:%M'
  else
    date -r "$epoch" '+%e %b %H:%M' | sed 's/^ //'
  fi
}

# A sign-in is saved when the Keychain has the extension's item (for any account). Never reads the secret.
signin_saved() { security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; }

# The extension state as a sentence part, e.g. "0.10.0 (enabled, work email set)".
describe_extension() {
  local version="$1" enabled="$2" email="$3" notes=()
  case "$enabled" in
    unknown) ;;
    blocked) notes+=("blocked by your organisation") ;;
    *) notes+=("$enabled") ;;
  esac
  # The work email is optional: say so only when one is set (sign-ins are then limited to that account).
  [[ "$email" != email-set ]] || notes+=("work email set")
  if [[ ${#notes[@]} -gt 0 ]]; then
    local joined
    joined="$(printf '%s, ' "${notes[@]}")"
    printf '%s (%s)\n' "$version" "${joined%, }"
  else
    printf '%s\n' "$version"
  fi
}

switch_on_hint() {
  echo "  In Claude Desktop open Settings > Extensions > $APP_TITLE and switch it on (click once, then wait a"
  echo "  few seconds)."
}

# The organisation hasn't approved the extension: the same release runs as an mcpServers entry. $1 = that command.
blocked_hint() {
  echo "  Your organisation hasn't approved Claude Desktop extensions like this one, so Claude Desktop keeps it"
  echo "  switched off. Install the same release as a Claude Desktop mcpServers entry instead:"
  echo "    $1"
  if [[ -z "$(find_uv)" ]]; then
    echo "  The entry needs uv, which isn't installed: the installer asks whether to install it (with no terminal,"
    echo "  add --install-uv once the user agrees)."
  fi
}

# ---- The mcpServers entry (--entry) ----

# The uv --entry uses, or nothing: the places the entry's command looks too (outlook_okta/managed.py). Always
# succeeds.
find_uv() {
  local candidates=() candidate
  if [[ -n "${OUTLOOK_INSTALL_UV+set}" ]]; then
    IFS=: read -r -a candidates <<<"$OUTLOOK_INSTALL_UV"
  else
    candidates=("$(command -v uv 2>/dev/null || true)" /opt/homebrew/bin/uv /usr/local/bin/uv "${HOME%/}/.local/bin/uv")
  fi
  [[ ${#candidates[@]} -gt 0 ]] || return 0
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -f "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 0
}

# Homebrew's brew, or nothing. Always succeeds.
find_brew() {
  if [[ -n "${OUTLOOK_INSTALL_BREW+set}" ]]; then
    if [[ -n "$OUTLOOK_INSTALL_BREW" && -x "$OUTLOOK_INSTALL_BREW" ]]; then printf '%s\n' "$OUTLOOK_INSTALL_BREW"; fi
    return 0
  fi
  local candidate
  for candidate in "$(command -v brew 2>/dev/null || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 0
}

# How install_uv would install uv, in words for the question and the help.
uv_install_how() {
  if [[ -n "$(find_brew)" ]]; then
    echo "with Homebrew (brew install uv)"
  else
    echo "uv $UV_VERSION from its GitHub release, checked against its SHA-256, into ~/.local/bin"
  fi
}

# Installs uv (only after the owner agreed, or --install-uv): with Homebrew if there is one, else uv's own release
# from GitHub, checked against the pinned SHA-256 before anything is unpacked, into ~/.local/bin. Never changes a
# shell profile and never replaces a uv that is there. Says why on failure.
install_uv() {
  local brew
  brew="$(find_brew)"
  if [[ -n "$brew" ]]; then
    print_step "Installing uv with Homebrew (brew install uv)..."
    "$brew" install uv || {
      print_error "brew install uv failed (its output is above)"
      return 1
    }
    return 0
  fi
  local arch expected name url tmp actual bin="${HOME%/}/.local/bin"
  case "$(uname -m)" in
    arm64 | aarch64) arch=aarch64 expected="$UV_SHA256_AARCH64" ;;
    x86_64) arch=x86_64 expected="$UV_SHA256_X86_64" ;;
    *)
      print_error "uv has no release for this Mac's processor ($(uname -m))"
      return 1
      ;;
  esac
  [[ -z "${OUTLOOK_INSTALL_UV_SHA256:-}" ]] || expected="$OUTLOOK_INSTALL_UV_SHA256"
  name="uv-$arch-apple-darwin"
  url="${OUTLOOK_INSTALL_UV_BASE:-https://github.com/astral-sh/uv/releases/download/$UV_VERSION}"
  url="${url%/}/$name.tar.gz"
  print_step "Installing uv $UV_VERSION from its GitHub release into ~/.local/bin..."
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/outlook-uv.XXXXXX")" || return 1
  if ! curl -fsSL "$url" -o "$tmp/uv.tar.gz"; then
    rm -rf "$tmp"
    print_error "Download failed: $url"
    return 1
  fi
  actual="$(sha256_of "$tmp/uv.tar.gz")"
  if [[ "$actual" != "$expected" ]]; then
    rm -rf "$tmp"
    print_error "uv's checksum doesn't match — uv wasn't installed"
    print_error "Expected: $expected"
    print_error "Got:      $actual"
    return 1
  fi
  if ! tar -xzf "$tmp/uv.tar.gz" -C "$tmp" "$name/uv" 2>/dev/null || [[ ! -f "$tmp/$name/uv" ]]; then
    rm -rf "$tmp"
    print_error "uv's release didn't hold $name/uv"
    return 1
  fi
  if [[ -e "$bin/uv" ]]; then
    rm -rf "$tmp"
    print_error "$bin/uv is there already but can't be run; leaving it alone"
    return 1
  fi
  if ! { mkdir -p "$bin" && install -m 755 "$tmp/$name/uv" "$bin/.uv.$$" && mv -f "$bin/.uv.$$" "$bin/uv"; }; then
    rm -rf "$tmp" "$bin/.uv.$$"
    print_error "Couldn't put uv in $bin"
    return 1
  fi
  rm -rf "$tmp"
  print_success "Installed uv $UV_VERSION in $bin (your shell profiles weren't changed; the entry finds it there)"
}

# The server's data folder, as outlook_okta/handles.py data_dir() finds it on macOS, spelt as Python's Path spells it
# (no "//", "/./" or trailing "/"), so the entry's command compares equal to the one the release writes.
entry_data_dir() {
  local d="${OUTLOOK_MAIL_DATA_DIR:-}"
  [[ -n "$d" ]] || d="${HOME%/}/Library/Application Support/outlook-okta"
  if [[ "$d" == \~ || "$d" == \~/* ]]; then d="$HOME${d:1}"; fi
  d="$(printf '%s\n' "$d" | sed -e 's#//*#/#g' -e ':a' -e 's#/\./#/#g' -e 'ta' -e 's#/\.$##')"
  [[ "$d" == / ]] || d="${d%/}"
  printf '%s\n' "$d"
}

# Claude Desktop's config file followed through symbolic links (a dotfile manager's, say), so it is read and changed
# where it really is and the link stays. $1 = the path Claude Desktop reads.
config_target() {
  local p="$1" t n=0
  while [[ -L "$p" && "$n" -lt 20 ]]; do
    t="$(readlink "$p")" || break
    [[ "$t" == /* ]] || t="$(dirname "$p")/$t"
    p="$t"
    n=$((n + 1))
  done
  printf '%s\n' "$p"
}

# The version of the release an entry runs ($1 = <server folder>/current/manifest.json), or "none".
release_version() {
  osascript -l JavaScript - "$1" <<'JXA' 2>/dev/null || echo none
ObjC.import("Foundation");
function run(argv) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(
    $(argv[0]).stringByResolvingSymlinksInPath,
    $.NSUTF8StringEncoding,
    null,
  );
  if (text.isNil()) return "none";
  try {
    const version = String(JSON.parse(text.js).version || "");
    return /^[0-9]+\.[0-9]+\.[0-9]+$/.test(version) ? version : "none";
  } catch (e) {
    return "none";
  }
}
JXA
}

# Reads or changes the entry in Claude Desktop's config file, with JavaScript for Automation (no jq, node or python).
#   entry_config state  <config> <launcher>
#     -> "missing" (no file), "invalid" (not a JSON object), "none" (no entry), "ours" (it runs <launcher>) or
#        "other" (it runs something else)
#   entry_config add    <config> <launcher> <uv folder> <out>
#   entry_config remove <config> <launcher> <out>
#     -> "changed" (the whole new file is written to <out>), "unchanged", "invalid", or for remove "other" (an
#        entry that runs something else is left alone). add keeps every other key; an entry that runs something
#        else is pointed at <launcher> and keeps its env (the owner's settings).
entry_config() {
  osascript -l JavaScript - "$ENTRY_NAME" "$@" <<'JXA' 2>/dev/null || echo error
ObjC.import("Foundation");
const isObject = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
function run(argv) {
  const [name, action, path, launcher] = argv;
  let config = {};
  if ($.NSFileManager.defaultManager.fileExistsAtPath(path)) {
    const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
    if (text.isNil()) return "invalid";
    try {
      config = JSON.parse(text.js);
    } catch (e) {
      return "invalid";
    }
    if (!isObject(config)) return "invalid";
  } else if (action === "state") {
    return "missing";
  }
  if (config.mcpServers !== undefined && !isObject(config.mcpServers)) return "invalid";
  const servers = config.mcpServers || {};
  const entry = servers[name];
  const ours = isObject(entry) && entry.command === launcher;
  if (action === "state") return entry === undefined ? "none" : ours ? "ours" : "other";
  let out;
  if (action === "remove") {
    if (entry === undefined) return "unchanged";
    if (!ours) return "other";
    delete servers[name];
    out = argv[4];
  } else if (action === "add") {
    if (ours) return "unchanged";
    if (isObject(entry)) {
      entry.command = launcher;
      entry.args = [];
    } else {
      const dirs = [argv[4], "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"];
      servers[name] = {
        command: launcher,
        args: [],
        env: { MCP_RUN_MODE: "config", PATH: dirs.filter((d, i) => d && dirs.indexOf(d) === i).join(":") },
      };
    }
    config.mcpServers = servers;
    out = argv[5];
  } else {
    return "error";
  }
  const ok = $(JSON.stringify(config, null, 2) + "\n").writeToFileAtomicallyEncodingError(
    out,
    false,
    $.NSUTF8StringEncoding,
    null,
  );
  return ok ? "changed" : "error";
}
JXA
}

# Puts the checked new config ($2, a file) in place of Claude Desktop's ($1), after copying the old one to
# <config>.bak-<date and time>-<random>, a name mktemp reserves (so runs at the same moment never share a backup), and
# keeps the old file's permissions. Prints the backup's path (nothing if there was no file).
replace_config() {
  local cfg="$1" new="$2" backup="" mode
  mkdir -p "$(dirname "$cfg")" || return 1
  if [[ -f "$cfg" ]]; then
    backup="$(mktemp "$cfg.bak-$(date '+%Y-%m-%dT%H%M%S')-XXXXXX")" || return 1
    cp -p "$cfg" "$backup" || return 1
    mode="$(stat -f '%Lp' "$cfg")" || return 1
    chmod "$mode" "$new" || return 1
  fi
  mv -f "$new" "$cfg" || return 1
  printf '%s\n' "$backup"
}

# The entry as JSON, for adding it by hand. $1 = the launcher, $2 = Claude Desktop's config file.
print_entry_by_hand() {
  local command
  command="$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  echo "To add it yourself: back up $2, put this inside its \"mcpServers\" object, then quit and reopen"
  echo "Claude Desktop:"
  echo ""
  echo "  \"$ENTRY_NAME\": {"
  echo "    \"command\": \"$command\","
  echo "    \"args\": [],"
  echo "    \"env\": { \"MCP_RUN_MODE\": \"config\" }"
  echo "  }"
  echo ""
}

# When a file or link last changed, as a UTC time in Claude Desktop's log format ("2026-11-16T07:55:49"), or nothing.
changed_at() {
  local epoch
  epoch="$(stat -f '%m' "$1" 2>/dev/null)" || return 0
  date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%S'
}

# The server state as words for --status. $1 = state, $2 = UTC time, $3 = error text.
describe_server() {
  case "$1" in
    running) echo "running since $(local_time "$2")" ;;
    starting) echo "starting since $(local_time "$2") (the first start downloads Python and the dependencies)" ;;
    stopped) echo "stopped at $(local_time "$2")" ;;
    failed) echo "failed at $(local_time "$2")${3:+: $3}" ;;
    *) echo "hasn't started yet" ;;
  esac
}

# The one thing left to do, or "" when the extension (or the entry) is ready. $1..$3 = extension state, $4 = its
# server state, $5 = Claude Desktop open (true/false), $6 = the --entry command; for the entry, $7 = its release
# ("none" if not installed), $8 = its config state (entry_config state), $9 = its server state, $10 = true when its
# server last started before the release in use was installed; $11 = true when uv is installed.
next_step() {
  local ext_version="$1" enabled="$2" email="$3" server="$4" open="$5" entry_cmd="$6"
  local release="${7:-none}" cfg_state="${8:-none}" entry_server="${9:-none}" stale="${10:-false}" has_uv="${11:-true}"
  if [[ "$release" != none || "$cfg_state" == ours || "$cfg_state" == other ]]; then
    if [[ "$has_uv" != true ]]; then
      echo "install uv, which the $ENTRY_NAME entry runs with (ask first): $entry_cmd --install-uv"
    elif [[ "$release" == none ]]; then
      echo "install the release for the $ENTRY_NAME entry: $entry_cmd"
    elif [[ "$cfg_state" == invalid ]]; then
      echo "Claude Desktop's claude_desktop_config.json can't be read as JSON: fix it, then run $entry_cmd"
    elif [[ "$cfg_state" != ours ]]; then
      echo "add the $ENTRY_NAME entry to Claude Desktop's config: $entry_cmd"
    elif [[ "$ext_version" != none && "$enabled" != disabled && "$enabled" != blocked ]]; then
      echo "switch the extension off (Settings > Extensions > $APP_TITLE): with the entry on too, Claude sees every tool twice."
    elif [[ "$open" != true ]]; then
      echo "open Claude Desktop."
    elif [[ "$entry_server" == failed ]]; then
      echo "quit and reopen Claude Desktop; if it still fails, see ~/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log."
    elif [[ "$entry_server" == none || "$entry_server" == stopped ]]; then
      echo "quit Claude Desktop (⌘Q) and open it again, so it starts the $ENTRY_NAME entry."
    elif [[ "$entry_server" == running && "$stale" == true ]]; then
      echo "quit Claude Desktop (⌘Q) and open it again, so it starts release $release."
    elif [[ "$entry_server" != running ]]; then
      echo "wait a minute and check again: Claude Desktop is starting the $ENTRY_NAME entry."
    fi
    return 0
  fi
  if [[ "$ext_version" == none ]]; then
    echo "run the install command, then click Install in Claude Desktop."
  elif [[ "$enabled" == blocked && "$has_uv" == true ]]; then
    echo "your organisation blocks the extension: install it as an mcpServers entry instead: $entry_cmd"
  elif [[ "$enabled" == blocked ]]; then
    echo "your organisation blocks the extension: install it as an mcpServers entry instead. It needs uv, which isn't installed: ask first, then $entry_cmd --install-uv"
  elif [[ "$enabled" == disabled ]]; then
    echo "switch the extension on in Claude Desktop: Settings > Extensions > $APP_TITLE."
  elif [[ "$open" != true ]]; then
    echo "open Claude Desktop."
  elif [[ "$server" == failed ]]; then
    echo "run the install command again; if it still fails, see ~/Library/Logs/Claude/mcp-server-$APP_TITLE.log."
  elif [[ "$server" != running ]]; then
    echo "wait a minute and check again: Claude Desktop is starting the extension."
  fi
}

print_status() {
  local dir="$1" base="$2" claude_app="$3" claude_support="$4" log_file="$5" entry_cmd="$6"
  local downloaded="" latest app_version state ext_version enabled email writes srv since err open=false next
  [[ -f "$dir/latest.version" ]] && downloaded="$(tr -d '[:space:]' <"$dir/latest.version" 2>/dev/null || true)"
  latest="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ -n "$latest" ]] || latest="unknown (couldn't reach $base)"
  state="$(claude_extension_state "$claude_support")"
  read -r ext_version enabled email writes <<<"$state"
  read -r srv since err <<<"$(server_state "$log_file")"
  claude_running && open=true
  # The mcpServers entry (--entry): its installed release, its line in Claude Desktop's config, its server.
  local server_dir release cfg cfg_state e_srv e_since e_err switched stale=false entry_used=false
  server_dir="$(entry_data_dir)/server"
  release="$(release_version "$server_dir/current/manifest.json")"
  cfg="$(config_target "$claude_support/claude_desktop_config.json")"
  cfg_state="$(entry_config state "$cfg" "$server_dir/$LAUNCHER_NAME")"
  read -r e_srv e_since e_err <<<"$(server_state "${HOME%/}/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log")"
  switched="$(changed_at "$server_dir/current")"
  if [[ "$e_srv" == running && -n "$switched" && "$e_since" < "$switched" ]]; then stale=true; fi
  if [[ "$release" != none || "$cfg_state" == ours || "$cfg_state" == other ]]; then entry_used=true; fi
  local uv_path has_uv=false
  uv_path="$(find_uv)"
  [[ -z "$uv_path" ]] || has_uv=true
  echo "$APP_TITLE"
  echo "  Download folder: $dir$([[ -d "$dir" ]] || echo " (missing)")"
  echo "  Downloaded:      ${downloaded:-nothing yet}"
  echo "  Latest:          $latest"
  if [[ -d "$claude_app" ]]; then
    app_version="$(claude_version "$claude_app")"
    echo "  Claude Desktop:  ${app_version:-version unknown} ($claude_app)$([[ "$open" == true ]] || echo ", not open")"
  else
    echo "  Claude Desktop:  not found at $claude_app"
  fi
  if [[ "$has_uv" == true ]]; then
    echo "  uv:              $uv_path"
  else
    echo "  uv:              not installed (only the mcpServers entry needs it; --entry offers to install it)"
  fi
  if [[ "$ext_version" == none ]]; then
    echo "  Extension:       not installed in Claude Desktop"
  else
    echo "  Extension:       $(describe_extension "$ext_version" "$enabled" "$email")"
    # Switched off by the organisation: its settings don't apply and its server never runs.
    if [[ "$enabled" != blocked ]]; then
      case "$writes" in
        writes-on) echo "  Write tools:     on (Claude can send email and change meetings, files and Teams messages)" ;;
        writes-off) echo "  Write tools:     off" ;;
      esac
    fi
    if [[ "$enabled" == blocked ]]; then
      :
    elif [[ "$open" == true ]]; then
      echo "  Server:          $(describe_server "$srv" "$since" "$err")"
    else
      echo "  Server:          not running (Claude Desktop isn't open)"
    fi
  fi
  if [[ "$entry_used" == true ]]; then
    local where
    case "$cfg_state" in
      ours) where="in Claude Desktop's config as $ENTRY_NAME" ;;
      other) where="Claude Desktop's $ENTRY_NAME entry runs something else" ;;
      invalid) where="Claude Desktop's config can't be read as JSON" ;;
      *) where="not in Claude Desktop's config" ;;
    esac
    if [[ "$release" == none ]]; then
      echo "  Entry:           no release installed in $server_dir; $where"
    else
      echo "  Entry:           release $release, $where"
    fi
    if [[ "$open" == true ]]; then
      echo "  Entry server:    $(describe_server "$e_srv" "$e_since" "$e_err")"
    else
      echo "  Entry server:    not running (Claude Desktop isn't open)"
    fi
  fi
  if signin_saved; then
    echo "  Sign-in:         saved in your Keychain"
  else
    echo "  Sign-in:         none saved (Claude shows a sign-in card the first time you ask it something)"
  fi
  next="$(next_step "$ext_version" "$enabled" "$email" "$srv" "$open" "$entry_cmd" \
    "$release" "$cfg_state" "$e_srv" "$stale" "$has_uv")"
  if [[ -n "$next" ]]; then
    echo "  Next:            $next"
  else
    echo "  Ready:           yes. Start a new chat in Claude Desktop and ask it about your mail."
  fi
  if [[ "$latest" != unknown* ]]; then
    if [[ "$entry_used" == true && "$latest" == *-* ]]; then
      echo "  The latest here is a pre-release: the mcpServers entry installs only stable releases."
    elif [[ "$entry_used" == true ]]; then
      if [[ "$release" == none ]] || version_older "$release" "$latest"; then
        echo "  Update available: click Update now on the update card in Claude, or run the --entry command again."
      else
        echo "  Up to date."
      fi
    elif [[ "$ext_version" == none ]] || version_older "$ext_version" "$latest"; then
      echo "  Update available: run the install command again."
    else
      echo "  Up to date."
    fi
  fi
}

# --entry: installs the verified release ($dir/latest.mcpb) with that release's own `outlook-mail install-release`,
# adds the outlook-m365 entry to Claude Desktop's config, and waits until Claude Desktop runs it. main has already
# checked the config and asked the owner: $6 = true when the config may be changed.
install_entry() {
  local dir="$1" version="$2" uv="$3" claude_app="$4" claude_support="$5" consent="$6" wait_secs="$7"
  local status_cmd="$8"
  local cfg
  cfg="$(config_target "$claude_support/claude_desktop_config.json")"
  local entry_log="${HOME%/}/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log"
  local server_dir before_release release launcher out
  server_dir="$(entry_data_dir)/server"
  before_release="$(release_version "$server_dir/current/manifest.json")"

  if [[ -n "$version" && "$before_release" == "$version" && -x "$server_dir/$LAUNCHER_NAME" ]]; then
    launcher="$server_dir/$LAUNCHER_NAME"
    print_success "Release $version is already installed in $server_dir"
  else
    print_step "Installing the release for the $ENTRY_NAME entry (uv sets up Python and the dependencies: about a minute the first time)..."
    local stage="$OUTLOOK_TEMP_DIR/release"
    mkdir -p "$stage"
    unzip -q -o "$dir/latest.mcpb" -d "$stage" >/dev/null 2>&1 || die "Couldn't unpack $dir/latest.mcpb"
    [[ -f "$stage/pyproject.toml" && -f "$stage/uv.lock" ]] || die "$dir/latest.mcpb isn't a release bundle"
    # The release installs itself (outlook_okta/managed.py): it checks the bundle again, unpacks it beside the
    # version in use, syncs its locked dependencies and switches to it. Claude Desktop's config isn't touched yet.
    if ! out="$(cd "$stage" && env -u VIRTUAL_ENV -u UV_PROJECT_ENVIRONMENT "$uv" run --frozen --quiet \
      --project "$stage" outlook-mail install-release --bundle "$dir/latest.mcpb" 2>&1)"; then
      print_error "Installing the release failed, so Claude Desktop's config wasn't changed:"
      printf '%s\n' "$out" | tail -n 15 >&2
      exit 1
    fi
    launcher="$(printf '%s\n' "$out" | sed -n 's/^Claude Desktop entry command: //p' | tail -n 1)"
    [[ -n "$launcher" && -x "$launcher" ]] || die "The release installed, but didn't say where its command is"
    server_dir="${launcher%/*}"
  fi
  release="$(release_version "$server_dir/current/manifest.json")"
  if [[ "$before_release" != none && "$before_release" != "$release" ]]; then
    print_success "Installed release $release (was $before_release) in $server_dir"
  elif [[ "$before_release" == none ]]; then
    print_success "Installed release $release in $server_dir"
  fi

  # Claude Desktop's config: add the entry, or point an existing one at this release, if the owner agreed.
  local cfg_state changed=false
  cfg_state="$(entry_config state "$cfg" "$launcher")"
  case "$cfg_state" in
    ours)
      print_success "Claude Desktop's config already has the $ENTRY_NAME entry"
      ;;
    none | missing | other)
      if [[ "$consent" != true ]]; then
        print_warning "Claude Desktop's config wasn't changed, as you chose."
        print_entry_by_hand "$launcher" "$cfg"
        return 0
      fi
      local new result backup
      new="$(mktemp "$OUTLOOK_TEMP_DIR/config.XXXXXX")" || die "Couldn't create a temporary file"
      result="$(entry_config add "$cfg" "$launcher" "${uv%/*}" "$new")"
      [[ "$result" == changed && "$(entry_config state "$new" "$launcher")" == ours ]] ||
        die "Couldn't prepare the new config ($result); $cfg wasn't changed"
      backup="$(replace_config "$cfg" "$new")" || die "Couldn't write $cfg"
      changed=true
      if [[ "$cfg_state" == other ]]; then
        print_success "Pointed Claude Desktop's $ENTRY_NAME entry at release $release${backup:+ (backup: $backup)}"
      else
        print_success "Added the $ENTRY_NAME entry to Claude Desktop's config${backup:+ (backup: $backup)}"
      fi
      ;;
    *)
      print_error "Claude Desktop's config can't be read as JSON, so it was left alone: $cfg"
      print_entry_by_hand "$launcher" "$cfg" >&2
      exit 1
      ;;
  esac

  local ext_version enabled _email _writes
  read -r ext_version enabled _email _writes <<<"$(claude_extension_state "$claude_support")"
  if [[ "$ext_version" != none && "$enabled" != disabled && "$enabled" != blocked ]]; then
    print_warning "The $APP_TITLE extension is switched on too, so Claude would see every tool twice."
    echo "  Switch it off in Claude Desktop: Settings > Extensions > $APP_TITLE."
  fi

  # Claude Desktop reads its config when it starts: wait for a start of the entry from now on (or, when nothing
  # changed, one that runs this release already).
  local start_ts already=false srv since err switched
  start_ts="$(date -u '+%Y-%m-%dT%H:%M:%S')"
  read -r srv since err <<<"$(server_state "$entry_log")"
  switched="$(changed_at "$server_dir/current")"
  if [[ "$changed" != true && "$srv" == running && -n "$switched" && ! "$since" < "$switched" ]] && claude_running; then
    already=true
  fi
  if [[ "$already" != true ]]; then
    echo ""
    if claude_running; then
      echo "In Claude Desktop: quit it (Claude > Quit Claude, or ⌘Q) and open it again, so it starts the"
      echo "$ENTRY_NAME entry."
    elif [[ "${OUTLOOK_INSTALL_NO_OPEN:-}" == "1" ]]; then
      print_step "Would open: open -a $(printf '%q' "$claude_app")"
    else
      print_step "Opening Claude Desktop..."
      open -a "$claude_app" || print_warning "Couldn't open Claude Desktop. Open it yourself."
    fi
    echo ""
  fi
  local ready=false waited=0
  while [[ "$already" != true ]]; do
    read -r srv since err <<<"$(server_state "$entry_log")"
    if [[ "$srv" == running && ! "$since" < "$start_ts" ]]; then
      ready=true
      break
    fi
    if [[ "$srv" == failed && ! "$since" < "$start_ts" ]]; then break; fi
    [[ "$waited" -lt "$wait_secs" ]] || break
    [[ "$waited" -ne 0 ]] || print_step "Waiting for Claude Desktop to start the $ENTRY_NAME entry (up to $((wait_secs / 60)) minutes)..."
    touch "$OUTLOOK_TEMP_DIR" 2>/dev/null || true
    sleep 2
    waited=$((waited + 2))
  done

  echo ""
  if [[ "$already" == true ]]; then
    print_success "Already up to date and running: the $ENTRY_NAME entry, release $release"
  elif [[ "$ready" == true ]]; then
    print_success "Installed and running: the $ENTRY_NAME entry, release $release"
  elif [[ "$srv" == failed && ! "$since" < "$start_ts" ]]; then
    print_error "Claude Desktop started the $ENTRY_NAME entry, but it failed${err:+: $err}"
    print_error "Quit and reopen Claude Desktop; if it still fails, see ~/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log."
    exit 1
  elif [[ "$wait_secs" -eq 0 ]]; then
    print_success "Done. Quit Claude Desktop (⌘Q) and open it again if it was open, so it starts the $ENTRY_NAME"
    echo "entry, then start a new chat."
    echo ""
    echo "Check the install any time with:"
    echo "  $status_cmd"
    return 0
  else
    print_error "Claude Desktop hasn't started the $ENTRY_NAME entry within $((wait_secs / 60)) minutes."
    print_error "Quit Claude Desktop (⌘Q) and open it again, then check with the --status command below."
    echo "Check the install any time with:"
    echo "  $status_cmd"
    exit 1
  fi
  echo ""
  echo "Next: start a new chat in Claude Desktop and ask \"What's in my inbox today?\". The first time, Claude"
  echo "shows a sign-in card: enter the code on the page that opens, sign in with your work account, and ask again."
  echo "Ask Claude to \"show my Outlook settings\" to change the settings (write tools, update check and more)."
  echo ""
  echo "Check the install any time with:"
  echo "  $status_cmd"
}

# --entry --uninstall: removes the outlook-m365 entry from Claude Desktop's config (only one that runs the installed
# release; a backup is kept) and the installed release. Settings and the saved sign-in are kept.
uninstall_entry() {
  local claude_support="$1" yes="$2"
  local cfg server_dir launcher cfg_state has_release=false
  cfg="$(config_target "$claude_support/claude_desktop_config.json")"
  server_dir="$(entry_data_dir)/server"
  launcher="$server_dir/$LAUNCHER_NAME"
  cfg_state="$(entry_config state "$cfg" "$launcher")"
  if [[ -f "$launcher" && -d "$server_dir/versions" ]]; then has_release=true; fi
  if [[ "$cfg_state" != ours && "$has_release" != true ]]; then
    [[ "$cfg_state" != other ]] || print_warning "Claude Desktop's $ENTRY_NAME entry runs something else; leaving it alone."
    die "Nothing to remove: no $ENTRY_NAME entry from this installer and no release in $server_dir"
  fi
  local what=()
  [[ "$cfg_state" != ours ]] || what+=("the $ENTRY_NAME entry in Claude Desktop's config (a backup is kept)")
  [[ "$has_release" != true ]] || what+=("the installed release in $server_dir")
  local question
  question="Remove $(printf '%s and ' "${what[@]}")"
  question="${question% and }?"
  if [[ "$yes" != true ]] && ! ask_yes_no "$question"; then
    die "Not removed (with no terminal, add --yes)"
  fi
  if [[ "$cfg_state" == ours ]]; then
    OUTLOOK_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/outlook-entry.XXXXXX")" || die "Couldn't create a temporary folder"
    trap cleanup_temp EXIT
    local new result backup
    new="$OUTLOOK_TEMP_DIR/config.json"
    : >"$new"
    chmod 600 "$new"
    result="$(entry_config remove "$cfg" "$launcher" "$new")"
    [[ "$result" == changed && "$(entry_config state "$new" "$launcher")" == none ]] ||
      die "Couldn't prepare the new config ($result); $cfg wasn't changed"
    backup="$(replace_config "$cfg" "$new")" || die "Couldn't write $cfg"
    print_success "Removed the $ENTRY_NAME entry from Claude Desktop's config${backup:+ (backup: $backup)}"
  elif [[ "$cfg_state" == other ]]; then
    print_warning "Claude Desktop's $ENTRY_NAME entry runs something else; left it alone."
  elif [[ "$cfg_state" == invalid || "$cfg_state" == error ]]; then
    print_warning "Claude Desktop's config can't be read as JSON, so an $ENTRY_NAME entry in it (if there is one) was"
    echo "  left alone: $cfg. Once the release is gone it would point at nothing: remove it from the file by hand."
  fi
  if [[ "$has_release" == true ]]; then
    rm -rf "${server_dir:?}"
    print_success "Removed $server_dir"
  fi
  echo "Quit Claude Desktop and open it again. Your settings ($(entry_data_dir)/settings.toml) are kept, and so is"
  echo "the saved sign-in: delete the $KEYCHAIN_SERVICE item in Keychain Access to remove it."
}

main() {
  [[ -n "${HOME:-}" ]] || die "HOME isn't set, so the installer can't find your home folder"
  local dir="" status_only=false uninstall=false yes=false no_wait=false entry=false install_uv_ok=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --entry)
        entry=true
        shift
        ;;
      --install-uv)
        install_uv_ok=true
        shift
        ;;
      --dir)
        [[ $# -ge 2 && -n "$2" ]] || die "--dir needs a folder path"
        dir="$2"
        shift 2
        ;;
      --dir=*)
        dir="${1#--dir=}"
        [[ -n "$dir" ]] || die "--dir needs a folder path"
        shift
        ;;
      --status)
        status_only=true
        shift
        ;;
      --no-wait)
        no_wait=true
        shift
        ;;
      --uninstall)
        uninstall=true
        shift
        ;;
      --yes | -y)
        yes=true
        shift
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      *) die "Unknown argument: $1 (try --help)" ;;
    esac
  done

  [[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS only: the extension runs in Claude Desktop on a Mac"
  if [[ "$install_uv_ok" == true && ("$entry" != true || "$uninstall" == true || "$status_only" == true) ]]; then
    die "--install-uv goes with --entry: the mcpServers entry is what needs uv"
  fi

  local default_dir="${HOME%/}/.outlook-mcp-server"
  [[ -n "$dir" ]] || dir="${OUTLOOK_MCP_HOME:-$default_dir}"
  # Expand a leading ~ (the shell doesn't when the path arrives quoted or via the environment).
  if [[ "$dir" == \~ || "$dir" == \~/* ]]; then dir="$HOME${dir:1}"; fi
  dir="${dir%/}"
  [[ "$dir" == /* ]] || die "The download folder must be an absolute path: $dir"
  case "/$dir/" in
    */../* | */./*) die "The download folder can't contain . or .. segments: $dir" ;;
  esac
  # Compare physical, lower-cased paths: macOS volumes are case-insensitive by default.
  local canon canon_home p
  canon="$(lowercase "$(canonical_path "$dir")")" || die "Can't resolve the download folder: $dir"
  canon_home="$(lowercase "$(canonical_path "$HOME")")" || die "Can't resolve your home folder"
  [[ "$canon" != "$canon_home" ]] || die "Can't use your home folder itself as the download folder"
  # Your own temporary folder lives under /var on macOS (/var/folders/.../T); it isn't a system location.
  local user_tmp
  user_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
  if [[ -n "$user_tmp" ]]; then user_tmp="$(lowercase "$(canonical_path "${user_tmp%/}")")" || user_tmp=""; fi
  if [[ -z "$user_tmp" || "$user_tmp" == "/" || ("$canon" != "$user_tmp" && "$canon" != "$user_tmp/"*) ]]; then
    for p in /Applications /System /Library /usr /bin /sbin /etc /private/etc /var /opt; do
      [[ -d "$p" ]] || continue
      local canon_p
      canon_p="$(lowercase "$(canonical_path "$p")")"
      if [[ "$canon" == "$canon_p" || "$canon" == "$canon_p/"* ]]; then
        die "Can't use a system location as the download folder: $dir"
      fi
    done
  fi

  OUTLOOK_INSTALL_TTY_PATH="${OUTLOOK_INSTALL_TTY:-/dev/tty}"
  local claude_app="${OUTLOOK_CLAUDE_APP:-/Applications/Claude.app}"
  local claude_support="${HOME%/}/Library/Application Support/Claude"
  # Claude Desktop's own log for this extension's server (named after its display name).
  local log_file="${HOME%/}/Library/Logs/Claude/mcp-server-$APP_TITLE.log"
  local base="${OUTLOOK_INSTALL_BASE:-$SITE_BASE_DEFAULT}"
  base="${base%/}"
  # Under curl | bash there is no local install.sh, so the pointers to --status spell out the whole command.
  # Every value is shell-quoted (printf %q) so the printed command can be pasted even when a path holds a
  # space, $, backtick, quote or backslash.
  local q_base q_dir status_cmd entry_cmd
  printf -v q_base '%q' "$base"
  printf -v q_dir '%q' "$dir"
  status_cmd="curl -fsSL $q_base/install.sh | bash -s -- --status"
  entry_cmd="curl -fsSL $q_base/install.sh | bash -s -- --entry"
  if [[ "$dir" != "$default_dir" ]]; then
    status_cmd+=" --dir $q_dir"
    entry_cmd+=" --dir $q_dir"
  fi

  if [[ "$status_only" == true ]]; then
    print_status "$dir" "$base" "$claude_app" "$claude_support" "$log_file" "$entry_cmd"
    return 0
  fi

  if [[ "$uninstall" == true && "$entry" == true ]]; then
    uninstall_entry "$claude_support" "$yes"
    return 0
  fi

  if [[ "$uninstall" == true ]]; then
    [[ -d "$dir" ]] || die "Nothing to remove: $dir doesn't exist"
    [[ -e "$dir/.outlook-mcp-server-home" ]] || die "$dir isn't an $APP_TITLE download folder; leaving it alone"
    if [[ "$yes" != true ]] && ! ask_yes_no "Remove $dir?"; then
      die "Not removed (with no terminal, add --yes)"
    fi
    rm -rf "${dir:?}"
    print_success "Removed $dir"
    echo "The extension itself is managed by Claude Desktop. To remove it, first ask Claude to \"Sign out of"
    echo "Outlook\" (that deletes the saved sign-in), then uninstall it in Settings > Extensions."
    return 0
  fi

  echo ""
  if [[ "$entry" == true ]]; then
    print_step "Installing $APP_TITLE as a Claude Desktop mcpServers entry ($ENTRY_NAME)"
  else
    print_step "Installing $APP_TITLE for Claude Desktop"
  fi
  echo ""

  print_step "Checking prerequisites..."
  local tool uv=""
  for tool in curl awk osascript open security; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not available"
  done
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || die "Neither sha256sum nor shasum is available"
  if [[ "$entry" == true ]]; then
    command -v unzip >/dev/null 2>&1 || die "unzip is not available"
  fi
  [[ -d "$claude_app" ]] || die "Claude Desktop not found at $claude_app. Install it from https://claude.ai/download, then run this again"
  local app_version
  app_version="$(claude_version "$claude_app")"
  if [[ -z "$app_version" ]]; then
    print_warning "Couldn't read Claude Desktop's version; the extension needs $MIN_CLAUDE_VERSION or later"
  elif ! version_ge "$app_version" "$MIN_CLAUDE_VERSION"; then
    die "Claude Desktop $app_version is too old: the extension needs $MIN_CLAUDE_VERSION or later. Update Claude Desktop (Claude > Check for Updates), then run this again"
  fi
  print_success "macOS and Claude Desktop ${app_version:-found}"

  # --entry: every check and question comes first, before anything is downloaded or installed.
  local need_uv=false cfg_consent=false
  if [[ "$entry" == true ]]; then
    # The entry installs only stable releases (outlook_okta/managed.py RELEASE); the pre-release site serves others.
    local site_version
    site_version="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$site_version" == *-* ]]; then
      die "This site serves a pre-release ($site_version), and the $ENTRY_NAME entry installs only stable releases. Nothing was changed. Use the stable site: curl -fsSL $SITE_BASE_STABLE/install.sh | bash -s -- --entry"
    fi
    # uv: the entry runs with it. Installing software is the owner's call: a question in a terminal, else
    # --install-uv (their go-ahead). It is installed only once the download has been checked, below.
    uv="$(find_uv)"
    if [[ -z "$uv" ]]; then
      local how
      how="$(uv_install_how)"
      print_warning "uv isn't installed, and the $ENTRY_NAME entry runs with it."
      if [[ "$install_uv_ok" == true ]] || ask_yes_no "Install uv now, $how?"; then
        need_uv=true
      elif can_answer; then
        die "uv wasn't installed, so nothing was changed. Install it yourself (brew install uv, or see https://docs.astral.sh/uv/getting-started/installation/), then run this again"
      else
        die "Nothing was changed. With the user's go-ahead, run this again with --install-uv to install uv $how; or install it yourself (brew install uv)"
      fi
    else
      print_success "uv: $uv"
    fi
    # Claude Desktop's config: the owner's go-ahead to change it, now rather than after a minute of installing.
    local cfg_path pre_state question
    cfg_path="$(config_target "$claude_support/claude_desktop_config.json")"
    pre_state="$(entry_config state "$cfg_path" "$(entry_data_dir)/server/$LAUNCHER_NAME")"
    case "$pre_state" in
      ours) cfg_consent=true ;;
      none | missing | other)
        if [[ "$pre_state" == other ]]; then
          question="Claude Desktop's $ENTRY_NAME entry runs something else. Point it at this release ($cfg_path; a backup is kept)?"
        else
          question="Add the $ENTRY_NAME entry to Claude Desktop's config ($cfg_path; a backup is kept)?"
        fi
        if [[ "$yes" == true ]] || ask_yes_no "$question"; then
          cfg_consent=true
        elif ! can_answer; then
          die "Nothing was changed. With the user's go-ahead to change Claude Desktop's config, run this again with --yes"
        fi
        ;;
      *)
        die "Claude Desktop's config can't be read as JSON, so nothing was changed: $cfg_path. Fix it (Claude Desktop needs valid JSON too), then run this again"
        ;;
    esac
  fi

  # The folder must be new, empty, or one of ours.
  if [[ -e "$dir" && ! -d "$dir" ]]; then die "Not a folder: $dir"; fi
  if [[ -d "$dir" ]]; then
    if [[ ! -e "$dir/.outlook-mcp-server-home" && -n "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .DS_Store 2>/dev/null)" ]]; then
      die "That folder is not empty and isn't an $APP_TITLE download folder: $dir"
    fi
    [[ -w "$dir" ]] || die "That folder isn't writable: $dir"
  else
    mkdir -p "$dir" || die "Couldn't create $dir"
    chmod 700 "$dir" || die "Couldn't set permissions on $dir"
  fi
  # Mark the folder as ours straight away, so a re-run after an interruption recognises it.
  touch "$dir/.outlook-mcp-server-home"
  # A run that was killed outright (no clean-up) leaves its temporary folder; a running one keeps its own fresh.
  find "$dir" -mindepth 1 -maxdepth 1 -type d -name '.download.*' -mtime +0 -exec rm -rf {} + 2>/dev/null || true
  print_success "Download folder: $dir"

  # Download into a temp folder and verify before anything is changed.
  OUTLOOK_TEMP_DIR="$(mktemp -d "$dir/.download.XXXXXX")" || die "Couldn't create a temporary folder"
  trap cleanup_temp EXIT

  print_step "Downloading the latest release..."
  curl -fsSL "$base/latest.mcpb" -o "$OUTLOOK_TEMP_DIR/latest.mcpb" || die "Download failed: $base/latest.mcpb"
  curl -fsSL "$base/latest.mcpb.sha256" -o "$OUTLOOK_TEMP_DIR/latest.mcpb.sha256" || die "Download failed: $base/latest.mcpb.sha256"
  local version=""
  if curl -fsSL "$base/latest.version" -o "$OUTLOOK_TEMP_DIR/latest.version" 2>/dev/null; then
    version="$(tr -d '[:space:]' <"$OUTLOOK_TEMP_DIR/latest.version")"
  fi
  [[ -z "$version" || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "The site's latest.version isn't a version number"

  local expected actual
  expected="$(awk 'NR == 1 { print tolower($1) }' "$OUTLOOK_TEMP_DIR/latest.mcpb.sha256")"
  actual="$(sha256_of "$OUTLOOK_TEMP_DIR/latest.mcpb")"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ || "$expected" != "$actual" ]]; then
    print_error "Checksum mismatch — nothing was installed"
    print_error "Expected: ${expected:-<none>}"
    print_error "Got:      $actual"
    print_error "This can happen for up to about 10 minutes while a new release propagates; wait and run the installer again."
    exit 1
  fi
  print_success "Downloaded and verified${version:+ version $version}"

  mv -f "$OUTLOOK_TEMP_DIR/latest.mcpb" "$dir/latest.mcpb"
  mv -f "$OUTLOOK_TEMP_DIR/latest.mcpb.sha256" "$dir/latest.mcpb.sha256"
  if [[ -n "$version" ]]; then mv -f "$OUTLOOK_TEMP_DIR/latest.version" "$dir/latest.version"; fi

  # How long to wait for Claude Desktop: until the extension (or the entry) is installed and running.
  local wait_secs="${OUTLOOK_INSTALL_WAIT_SECS:-}"
  if [[ -z "$wait_secs" ]]; then
    if [[ "${OUTLOOK_INSTALL_NO_OPEN:-}" == "1" ]]; then wait_secs=0; else wait_secs=600; fi
  fi
  [[ "$wait_secs" =~ ^[0-9]+$ ]] || die "OUTLOOK_INSTALL_WAIT_SECS must be a whole number of seconds"
  if [[ "$no_wait" == true ]]; then wait_secs=0; fi

  if [[ "$entry" == true ]]; then
    if [[ "$version" == *-* ]]; then
      die "This site serves a pre-release ($version), and the $ENTRY_NAME entry installs only stable releases. The verified download is kept in $dir; nothing else was changed"
    fi
    if [[ "$need_uv" == true ]]; then
      install_uv || die "uv wasn't installed, so the entry wasn't set up (only the verified download is kept, in $dir). Install uv yourself (see https://docs.astral.sh/uv/getting-started/installation/), then run this again"
      uv="$(find_uv)"
      [[ -n "$uv" ]] || die "uv was installed, but the installer can't find it (looked in your PATH, /opt/homebrew/bin, /usr/local/bin and ~/.local/bin)"
      print_success "uv: $uv"
    fi
    install_entry "$dir" "$version" "$uv" "$claude_app" "$claude_support" "$cfg_consent" "$wait_secs" "$status_cmd"
    return 0
  fi

  local before before_version before_enabled _email _writes
  before="$(claude_extension_state "$claude_support")"
  read -r before_version before_enabled _email _writes <<<"$before"
  # Server starts logged from now on belong to this install.
  local start_ts
  start_ts="$(date -u '+%Y-%m-%dT%H:%M:%S')"

  # Installing again doesn't help when the organisation blocks the extension: say what does.
  if [[ "$before_enabled" == blocked ]]; then
    print_error "Claude Desktop has $APP_TITLE $before_version, but your organisation blocks the extension."
    blocked_hint "$entry_cmd" >&2
    exit 1
  fi

  local already=false
  if [[ -n "$version" && "$before_version" == "$version" ]]; then
    already=true
  elif [[ "${OUTLOOK_INSTALL_NO_OPEN:-}" == "1" ]]; then
    print_step "Would open: open -a $(printf '%q' "$claude_app") $(printf '%q' "$dir/latest.mcpb")"
  else
    print_step "Opening Claude Desktop's install dialog..."
    open -a "$claude_app" "$dir/latest.mcpb" ||
      print_warning "Couldn't open it automatically. Double-click $dir/latest.mcpb to install it."
  fi

  if [[ "$already" != true ]]; then
    echo ""
    echo "In Claude Desktop:"
    if [[ "$before_version" == none ]]; then
      echo "  1. Click Install. You can leave the settings blank: you choose your work account the first time"
      echo "     you sign in."
      echo "  2. If Claude Desktop shows the extension switched off, switch it on: Settings > Extensions >"
      echo "     $APP_TITLE (click once, then wait a few seconds)."
    else
      if [[ -n "$version" ]] && version_older "$version" "$before_version"; then
        echo "  Click Install to replace $before_version with $version, an earlier version. Your settings and your"
        echo "  sign-in are kept."
      else
        echo "  Click Install to update from $before_version. Your settings and your sign-in are kept."
      fi
    fi
    echo ""
  fi

  # Wait until the extension is installed at this version, switched on and running: Claude Desktop's list says the
  # first two, its log for the extension says whether the server started after this install.
  if [[ "$already" == true ]]; then wait_secs=0; fi
  local state ext_version enabled email writes srv since err listed ready=false open waited=0
  local hinted_off=false hinted_start=false
  while :; do
    state="$(claude_extension_state "$claude_support")"
    read -r ext_version enabled email writes <<<"$state"
    read -r srv since err <<<"$(server_state "$log_file")"
    open=false
    claude_running && open=true
    listed=false
    if [[ "$ext_version" != none ]]; then
      if [[ -n "$version" && "$ext_version" == "$version" ]] ||
        [[ -z "$version" && ("$already" == true || "$ext_version" != "$before_version") ]]; then listed=true; fi
    fi
    if [[ "$listed" == true && "$enabled" != disabled && "$enabled" != blocked && "$open" == true && "$srv" == running ]] &&
      [[ "$already" == true || ! "$since" < "$start_ts" ]]; then
      ready=true
      break
    fi
    if [[ "$listed" == true && "$enabled" == blocked ]]; then break; fi
    [[ "$waited" -lt "$wait_secs" ]] || break
    [[ "$waited" -ne 0 ]] || print_step "Waiting for you to finish in Claude Desktop (up to $((wait_secs / 60)) minutes)..."
    if [[ "$listed" == true && "$enabled" == disabled && "$hinted_off" != true && "$waited" -ge 4 ]]; then
      print_warning "Claude Desktop installed it, but the extension is switched off."
      switch_on_hint
      hinted_off=true
    fi
    if [[ "$listed" == true && "$enabled" == enabled && "$srv" == starting && "$hinted_start" != true ]]; then
      print_step "Claude Desktop is starting the extension (the first start downloads Python and the dependencies, about a minute)..."
      hinted_start=true
    fi
    # Keep the temp folder fresh so nothing mistakes a long wait for a leftover.
    touch "$OUTLOOK_TEMP_DIR" 2>/dev/null || true
    sleep 2
    waited=$((waited + 2))
  done

  # Claude Desktop can still remove or switch off an extension right after installing it (Settings > Extensions):
  # look again after a few seconds.
  if [[ "$ready" == true && "$already" != true && "$wait_secs" -gt 0 ]]; then
    local settle="${OUTLOOK_INSTALL_SETTLE_SECS:-5}"
    [[ "$settle" =~ ^[0-9]+$ ]] || settle=5
    sleep "$settle"
    read -r ext_version enabled email writes <<<"$(claude_extension_state "$claude_support")"
    if [[ "$ext_version" == none ]]; then
      echo ""
      print_error "Claude Desktop removed the extension again just after installing it (Settings > Extensions > Uninstall?)."
      print_error "Run the install command again, and leave the extension installed and switched on."
      exit 1
    fi
    if [[ "$enabled" == blocked ]]; then
      echo ""
      print_error "The extension was installed, then switched off: your organisation blocks it."
      blocked_hint "$entry_cmd" >&2
      exit 1
    fi
    if [[ "$enabled" == disabled ]]; then
      echo ""
      print_error "The extension was installed, then switched off again."
      switch_on_hint >&2
      exit 1
    fi
  fi

  echo ""
  local summary
  summary="$APP_TITLE $(describe_extension "$ext_version" "$enabled" "$email")"
  if [[ "$ready" == true ]]; then
    if [[ "$already" == true ]]; then
      print_success "Already up to date and running: $summary"
    else
      print_success "Installed and running: $summary"
    fi
    if [[ "$writes" == writes-on ]]; then
      echo "Write tools are on: Claude can send email and change meetings, files and Teams messages (it shows you"
      echo "what it will do first). Turn them off in Settings > Extensions > $APP_TITLE > Configure."
    fi
    # The mcpServers entry from --entry, if it is there too, would give Claude every tool twice.
    if [[ "$(entry_config state "$(config_target "$claude_support/claude_desktop_config.json")" \
      "$(entry_data_dir)/server/$LAUNCHER_NAME")" == ours ]]; then
      print_warning "The $ENTRY_NAME mcpServers entry is set up too, so Claude would see every tool twice. Keep one:"
      echo "  remove the entry with: curl -fsSL $q_base/install.sh | bash -s -- --entry --uninstall"
      echo "  or switch the extension off in Settings > Extensions > $APP_TITLE."
    fi
    echo ""
    echo "Next: start a new chat in Claude Desktop (chats opened before the extension was on don't see its tools)"
    echo "and ask \"What's in my inbox today?\". The first time, Claude shows a sign-in card: enter the code on the"
    echo "page that opens, sign in with your work account, and ask again."
  elif [[ "$listed" == true && "$enabled" == blocked ]]; then
    print_error "Claude Desktop installed $APP_TITLE $ext_version, but your organisation blocks the extension."
    blocked_hint "$entry_cmd" >&2
    exit 1
  elif [[ "$listed" == true && "$enabled" == disabled && ("$wait_secs" -gt 0 || "$already" == true) ]]; then
    print_error "Claude Desktop has $summary, but the extension is switched off:"
    switch_on_hint >&2
    exit 1
  elif [[ "$listed" == true && "$open" != true ]]; then
    print_warning "Claude Desktop has $summary, but Claude Desktop isn't open. Open it to start the extension."
  elif [[ "$listed" == true && "$srv" == failed && ("$wait_secs" -gt 0 || "$already" == true) ]]; then
    print_error "Claude Desktop has $summary, but its server failed to start${err:+: $err}"
    print_error "Run the install command again; if it still fails, see ~/Library/Logs/Claude/mcp-server-$APP_TITLE.log."
    exit 1
  elif [[ "$listed" == true && "$wait_secs" -gt 0 ]]; then
    print_error "Claude Desktop has $summary, but hasn't started it within $((wait_secs / 60)) minutes."
    print_error "Check again in a minute with the --status command below; if it still hasn't started, run the install command again."
    echo "Check the install any time with:"
    echo "  $status_cmd"
    exit 1
  elif [[ "$listed" == true ]]; then
    print_success "Claude Desktop has $summary. It isn't running yet: check again in a minute with the --status command below."
  elif [[ "$wait_secs" -eq 0 ]]; then
    print_success "Done. Finish in Claude Desktop: click Install and make sure the extension is switched on. Then"
    echo "start a new chat."
  else
    print_error "Claude Desktop doesn't list version ${version:-the new version} yet."
    print_error "If you closed the install dialog, run the install command again; or double-click $dir/latest.mcpb."
    echo "Check the install any time with:"
    echo "  $status_cmd"
    exit 1
  fi
  echo ""
  echo "Check the install any time with:"
  echo "  $status_cmd"
}

main "$@"
