#!/bin/bash
# AUTO-GENERATED: Published to GitHub Pages by CI on each tagged release.
# Do not edit the published copy — edit install.sh in the outlook-okta repository instead.
#
# Installs the latest Outlook Mail, Calendar, Teams and OneDrive extension (.mcpb) into Claude Desktop (macOS).
#   curl -fsSL https://wpp-jamie-mills.github.io/outlook-mcp-server-site/install.sh | bash
# For an AI agent or a script (no terminal: it never prompts, and doesn't wait for the install dialog):
#   curl -fsSL <same url> | OUTLOOK_INSTALL_TTY=/dev/null bash -s -- --no-wait
#
# Environment overrides (mainly for tests):
#   OUTLOOK_MCP_HOME           download folder (--dir wins; default ~/.outlook-mcp-server)
#   OUTLOOK_INSTALL_BASE       base URL for the download files (default: the GitHub Pages site)
#   OUTLOOK_INSTALL_TTY        where questions are read from (default /dev/tty; /dev/null = no terminal)
#   OUTLOOK_CLAUDE_APP         path to Claude.app (default /Applications/Claude.app)
#   OUTLOOK_INSTALL_NO_OPEN    1 = don't open Claude Desktop's install dialog; just say what would happen
#   OUTLOOK_INSTALL_WAIT_SECS  how long to wait for the extension to be installed, switched on and running
#                              (default 600; 0 with --no-wait or OUTLOOK_INSTALL_NO_OPEN=1)
#   OUTLOOK_INSTALL_SETTLE_SECS  after that, how long to wait before checking it is still there (default 5)
set -euo pipefail

# Default download base (the prerelease copy is rewritten to point at /rc). Exactly one such line.
SITE_BASE_DEFAULT="https://wpp-jamie-mills.github.io/outlook-mcp-server-site"

APP_TITLE="Outlook Mail, Calendar, Teams and OneDrive"
# The oldest Claude Desktop the extension supports (manifest.json compatibility.claude_desktop).
MIN_CLAUDE_VERSION="2.7032.0"
# The Keychain item holding the saved sign-in (outlook_okta/auth.py KEYCHAIN_SERVICE). Only its presence is checked.
KEYCHAIN_SERVICE="outlook-okta-refresh-token"

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

It downloads the latest extension (.mcpb), checks its SHA-256 before anything changes, opens Claude Desktop's
install dialog, and waits until the extension is installed, switched on and running. Click Install there. Running
it again updates the extension and keeps your settings and your sign-in.

Options:
  --dir <path>   Folder for the downloaded extension (default: ~/.outlook-mcp-server).
  --status       Print what is installed (download, Claude Desktop, the extension and whether it is switched
                 on, write tools, whether its server is running, whether a sign-in is saved), the latest
                 version, and the one thing left to do ("Next:") or "Ready:". Never prints the sign-in or the
                 email address.
  --no-wait      Open Claude Desktop's install dialog and exit without waiting for you to click Install
                 (same as OUTLOOK_INSTALL_WAIT_SECS=0). Check later with --status: exit 0 means the
                 installer finished its steps, not that Claude Desktop installed the extension.
  --uninstall    Remove the download folder (asks first; with no terminal, add --yes). The extension itself
                 is removed in Claude Desktop: Settings > Extensions.
  --yes          Answer yes to the uninstall question.
  --help         Show this help.

Environment:
  OUTLOOK_MCP_HOME
      Same as --dir (--dir wins).
  OUTLOOK_INSTALL_TTY
      Where questions are read from; /dev/null means no terminal (every answer is no).
  OUTLOOK_INSTALL_BASE
      Where the release files are downloaded from (default: the project site). For testing.
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

# Claude Desktop's version (CFBundleShortVersionString), or nothing if it can't be read.
claude_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null || true
}

# What Claude Desktop lists for this extension, read with JavaScript for Automation (no jq, node or python):
#   "<version> <enabled|disabled|unknown> <email-set|email-missing|unknown> <writes-on|writes-off|unknown>", or
#   "none" when it isn't installed. $1 = Claude Desktop's Application Support folder. Never prints the email address.
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
# A reply logged after a shutdown (a late answer from a server being stopped) doesn't count as running.
server_state() {
  [[ -f "$1" ]] || {
    echo none
    return 0
  }
  tail -n 4000 "$1" | awk '
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
  [[ "$enabled" == unknown ]] || notes+=("$enabled")
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

# The one thing left to do, or "" when the extension is ready. $1..$4 = extension state, $5 = server state,
# $6 = Claude Desktop open (true/false).
next_step() {
  local ext_version="$1" enabled="$2" email="$3" server="$4" open="$5"
  if [[ "$ext_version" == none ]]; then
    echo "run the install command, then click Install in Claude Desktop."
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
  local dir="$1" base="$2" claude_app="$3" claude_support="$4" log_file="$5"
  local downloaded="" latest app_version state ext_version enabled email writes srv since err open=false next
  [[ -f "$dir/latest.version" ]] && downloaded="$(tr -d '[:space:]' <"$dir/latest.version")"
  latest="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ -n "$latest" ]] || latest="unknown (couldn't reach $base)"
  state="$(claude_extension_state "$claude_support")"
  read -r ext_version enabled email writes <<<"$state"
  read -r srv since err <<<"$(server_state "$log_file")"
  claude_running && open=true
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
  if [[ "$ext_version" == none ]]; then
    echo "  Extension:       not installed in Claude Desktop"
  else
    echo "  Extension:       $(describe_extension "$ext_version" "$enabled" "$email")"
    case "$writes" in
      writes-on) echo "  Write tools:     on (Claude can send email and change meetings, files and Teams messages)" ;;
      writes-off) echo "  Write tools:     off" ;;
    esac
    if [[ "$open" == true ]]; then
      echo "  Server:          $(describe_server "$srv" "$since" "$err")"
    else
      echo "  Server:          not running (Claude Desktop isn't open)"
    fi
  fi
  if signin_saved; then
    echo "  Sign-in:         saved in your Keychain"
  else
    echo "  Sign-in:         none saved (Claude shows a sign-in card the first time you ask it something)"
  fi
  next="$(next_step "$ext_version" "$enabled" "$email" "$srv" "$open")"
  if [[ -n "$next" ]]; then
    echo "  Next:            $next"
  else
    echo "  Ready:           yes. Start a new chat in Claude Desktop and ask it about your mail."
  fi
  if [[ "$latest" != unknown* ]]; then
    if [[ "$ext_version" == none || "$ext_version" != "$latest" ]]; then
      echo "  Update available: run the install command again."
    else
      echo "  Up to date."
    fi
  fi
}

main() {
  [[ -n "${HOME:-}" ]] || die "HOME isn't set, so the installer can't find your home folder"
  local dir="" status_only=false uninstall=false yes=false no_wait=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
  local q_base q_dir status_cmd
  printf -v q_base '%q' "$base"
  printf -v q_dir '%q' "$dir"
  status_cmd="curl -fsSL $q_base/install.sh | bash -s -- --status"
  [[ "$dir" == "$default_dir" ]] || status_cmd+=" --dir $q_dir"

  if [[ "$status_only" == true ]]; then
    print_status "$dir" "$base" "$claude_app" "$claude_support" "$log_file"
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
  print_step "Installing $APP_TITLE for Claude Desktop"
  echo ""

  print_step "Checking prerequisites..."
  local tool
  for tool in curl awk osascript open security; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not available"
  done
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || die "Neither sha256sum nor shasum is available"
  [[ -d "$claude_app" ]] || die "Claude Desktop not found at $claude_app. Install it from https://claude.ai/download, then run this again"
  local app_version
  app_version="$(claude_version "$claude_app")"
  if [[ -z "$app_version" ]]; then
    print_warning "Couldn't read Claude Desktop's version; the extension needs $MIN_CLAUDE_VERSION or later"
  elif ! version_ge "$app_version" "$MIN_CLAUDE_VERSION"; then
    die "Claude Desktop $app_version is too old: the extension needs $MIN_CLAUDE_VERSION or later. Update Claude Desktop (Claude > Check for Updates), then run this again"
  fi
  print_success "macOS and Claude Desktop ${app_version:-found}"

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

  local before before_version _enabled _email _writes
  before="$(claude_extension_state "$claude_support")"
  read -r before_version _enabled _email _writes <<<"$before"
  # Server starts logged from now on belong to this install.
  local start_ts
  start_ts="$(date -u '+%Y-%m-%dT%H:%M:%S')"

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
      echo "  Click Install to update from $before_version. Your settings and your sign-in are kept."
    fi
    echo ""
  fi

  # Wait until the extension is installed at this version, switched on and running: Claude Desktop's list says the
  # first two, its log for the extension says whether the server started after this install.
  local wait_secs="${OUTLOOK_INSTALL_WAIT_SECS:-}"
  if [[ -z "$wait_secs" ]]; then
    if [[ "${OUTLOOK_INSTALL_NO_OPEN:-}" == "1" ]]; then wait_secs=0; else wait_secs=600; fi
  fi
  [[ "$wait_secs" =~ ^[0-9]+$ ]] || die "OUTLOOK_INSTALL_WAIT_SECS must be a whole number of seconds"
  if [[ "$no_wait" == true || "$already" == true ]]; then wait_secs=0; fi
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
    if [[ "$listed" == true && "$enabled" != disabled && "$open" == true && "$srv" == running ]] &&
      [[ "$already" == true || ! "$since" < "$start_ts" ]]; then
      ready=true
      break
    fi
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
    echo ""
    echo "Next: start a new chat in Claude Desktop (chats opened before the extension was on don't see its tools)"
    echo "and ask \"What's in my inbox today?\". The first time, Claude shows a sign-in card: enter the code on the"
    echo "page that opens, sign in with your work account, and ask again."
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
