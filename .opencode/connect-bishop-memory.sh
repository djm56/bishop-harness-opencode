#!/bin/bash
#
# .opencode/connect-bishop-memory.sh
#
# Connection helper for the optional bishop-memory central-memory addon.
#
# Reads .opencode/bishop-memory.conf and registers the bishop-memory MCP adapter
# (mcpd) in the project's opencode.json under the `mcp` block. This is the
# opt-in runtime step that turns central mode on; the committed harness repo
# deliberately has no `mcp` block.
#
# Usage:
#   .opencode/connect-bishop-memory.sh [--dry-run]
#
# Requirements:
#   - .opencode/bishop-memory.conf exists with BISHOP_MEMORY_MODE=central
#   - BISHOP_HARNESS set to a unique harness name in that conf
#   - python3 (preferred) or jq available for JSON editing
#   - The bishop-memory service built and running on BISHOP_MEMORY_URL
#
# The binary path is configurable:
#   - The script first honours BISHOP_MEMORY_HOME from the conf file.
#   - If the conf leaves it empty, it falls back to the BISHOP_MEMORY_HOME
#     environment variable.
#   - If neither is set, it assumes bishop-memory is a sibling checkout of this
#     harness repo: <parent-of-this-repo>/bishop-memory/bin/mcpd.
#

set -euo pipefail

DRY_RUN=false

log_info() { printf '[connect-bishop-memory] %s\n' "$*"; }
log_warn() { printf '[connect-bishop-memory] WARN: %s\n' "$*" >&2; }
log_error() { printf '[connect-bishop-memory] ERROR: %s\n' "$*" >&2; }

die() {
  log_error "$1"
  exit 1
}

usage() {
  cat <<'EOF'
Usage: .opencode/connect-bishop-memory.sh [--dry-run]

  --dry-run   Print what would change without writing opencode.json.
  --help      Show this message.

The helper reads .opencode/bishop-memory.conf and, in central mode, registers
mcpd in opencode.json. It is idempotent: re-running updates the existing entry
only when the configuration has changed.
EOF
}

# Resolve absolute path without requiring realpath(1), which is not portable.
make_absolute() {
  local target="$1"
  local dir

  if [ -d "$target" ]; then
    (cd "$target" && pwd)
    return
  fi

  dir=$(dirname "$target")
  if [ -d "$dir" ]; then
    dir=$(cd "$dir" && pwd)
    printf '%s/%s\n' "$dir" "$(basename "$target")"
    return
  fi

  case "$target" in
    /*) printf '%s\n' "$target" ;;
    *) printf '%s/%s\n' "$(pwd)" "$target" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF_FILE="$PROJECT_ROOT/.opencode/bishop-memory.conf"
OPENCODE_JSON="$PROJECT_ROOT/opencode.json"
LIB_FILE="$PROJECT_ROOT/.opencode/lib/bishop-memory-conf.sh"

if [ ! -f "$LIB_FILE" ]; then
  die "parser library missing: $LIB_FILE"
fi

# Save any environment override before sourcing the conf parser, because the
# parser will overwrite BISHOP_MEMORY_HOME with the (possibly empty) conf value.
BISHOP_MEMORY_HOME_FROM_ENV="${BISHOP_MEMORY_HOME:-}"

# shellcheck source=.opencode/lib/bishop-memory-conf.sh
. "$LIB_FILE" || die "failed to source $LIB_FILE"

if ! bishop_memory_read_conf "$CONF_FILE"; then
  die "could not read $CONF_FILE — create it from .opencode/bishop-memory.conf.example first"
fi

if [ "$BISHOP_MEMORY_MODE" != "central" ]; then
  log_info "BISHOP_MEMORY_MODE is '${BISHOP_MEMORY_MODE:-standalone}'; central mode not requested. No MCP registration written."
  exit 0
fi

# URL has a documented default in the example; apply it if the conf is silent.
BISHOP_MEMORY_URL="${BISHOP_MEMORY_URL:-http://127.0.0.1:8787}"

if [ -z "$BISHOP_HARNESS" ]; then
  die "BISHOP_HARNESS is required in $CONF_FILE for central mode (set a unique harness name)"
fi

if ! [[ "$BISHOP_HARNESS" =~ ^[A-Za-z0-9_-]+$ ]]; then
  die "BISHOP_HARNESS must contain only letters, digits, hyphens, and underscores: $BISHOP_HARNESS"
fi

# Resolve the bishop-memory checkout directory and mcpd binary path.
if [ -z "$BISHOP_MEMORY_HOME" ]; then
  BISHOP_MEMORY_HOME="${BISHOP_MEMORY_HOME_FROM_ENV:-}"
fi
if [ -z "$BISHOP_MEMORY_HOME" ]; then
  # Default assumption documented in the header: sibling checkout.
  BISHOP_MEMORY_HOME="$(cd "$PROJECT_ROOT/.." && pwd)/bishop-memory"
fi

MCPD_PATH="$BISHOP_MEMORY_HOME/bin/mcpd"
if [ ! -f "$MCPD_PATH" ]; then
  log_warn "mcpd binary not found at $MCPD_PATH — check BISHOP_MEMORY_HOME or build the service"
fi

MCPD_ABS="$(make_absolute "$MCPD_PATH")"

# Edit opencode.json with python3 if available, otherwise jq. Both paths are
# idempotent: they only write when the entry would change, and they back up the
# original file once with a .bak suffix.
#
# The MCP registration entry is built INSIDE each branch rather than once at the
# top level. This preserves the python3-primary / jq-fallback contract: on a
# python3-only machine we must never invoke jq before the dispatch.
update_with_python() {
  if [ "$DRY_RUN" = true ]; then
    log_info "(dry-run) would register mcp.bishop-memory in $OPENCODE_JSON"
    return
  fi

  python3 - "$OPENCODE_JSON" "$MCPD_ABS" "$BISHOP_MEMORY_URL" "$BISHOP_HARNESS" <<'PY'
import json
import os
import shutil
import sys

path = sys.argv[1]
entry = {
    "type": "local",
    "command": [sys.argv[2]],
    "environment": {
        "BISHOP_MEMORY_URL": sys.argv[3],
        "BISHOP_HARNESS": sys.argv[4],
    },
    "enabled": True,
}

if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            cfg = json.load(f)
    except json.JSONDecodeError as exc:
        print(f"ERROR: {path} is not valid JSON: {exc}", file=sys.stderr)
        sys.exit(1)
else:
    cfg = {}

existing = cfg.get("mcp", {}).get("bishop-memory")
if existing == entry:
    print(f"No change needed; mcp.bishop-memory is already registered in {path}.")
    sys.exit(0)

cfg.setdefault("mcp", {})["bishop-memory"] = entry

backup_path = path + ".bak"
if os.path.exists(path) and not os.path.exists(backup_path):
    shutil.copy2(path, backup_path)

with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"Registered mcp.bishop-memory in {path}.")
PY
}

update_with_jq() {
  if [ "$DRY_RUN" = true ]; then
    log_info "(dry-run) would register mcp.bishop-memory in $OPENCODE_JSON"
    return
  fi

  # Build the opencode MCP registration entry matching the shape produced by
  # bishop-memory/scripts/install-opencode.sh. This is done here, inside the jq
  # branch, so a python3-only machine never reaches this jq invocation.
  local MCP_ENTRY
  MCP_ENTRY=$(jq -n \
    --arg cmd "$MCPD_ABS" \
    --arg url "$BISHOP_MEMORY_URL" \
    --arg harness "$BISHOP_HARNESS" \
    '{
      type: "local",
      command: [$cmd],
      environment: {
        BISHOP_MEMORY_URL: $url,
        BISHOP_HARNESS: $harness
      },
      enabled: true
    }')

  if [ ! -f "$OPENCODE_JSON" ]; then
    jq -n --argjson entry "$MCP_ENTRY" '{ mcp: { "bishop-memory": $entry } }' > "$OPENCODE_JSON"
    printf '{\n  "mcp": {\n    "bishop-memory": ...\n  }\n}\n'
    return
  fi

  local tmp
  tmp=$(mktemp)
  jq --argjson entry "$MCP_ENTRY" '.mcp //= {} | .mcp["bishop-memory"] = $entry' "$OPENCODE_JSON" > "$tmp"

  if cmp -s "$OPENCODE_JSON" "$tmp"; then
    rm "$tmp"
    log_info "No change needed; mcp.bishop-memory is already registered in $OPENCODE_JSON."
    return
  fi

  if [ ! -f "$OPENCODE_JSON.bak" ]; then
    cp "$OPENCODE_JSON" "$OPENCODE_JSON.bak"
  fi

  mv "$tmp" "$OPENCODE_JSON"
  log_info "Registered mcp.bishop-memory in $OPENCODE_JSON."
}

if command -v python3 >/dev/null 2>&1; then
  update_with_python
elif command -v jq >/dev/null 2>&1; then
  update_with_jq
else
  die "python3 or jq is required to edit $OPENCODE_JSON safely"
fi

# Best-effort health check. A failure here is not fatal because the service may
# simply not be running yet; the operator can start it before restarting opencode.
if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS --max-time 2 "${BISHOP_MEMORY_URL%/}/healthz" >/dev/null 2>&1; then
    log_warn "bishop-memory health check failed at ${BISHOP_MEMORY_URL%/}/healthz — start the service before restarting opencode"
  else
    log_info "bishop-memory health check passed."
  fi
fi

log_info "Next steps:"
log_info "  1. Restart opencode in this project."
log_info "  2. Approve the project-scope 'bishop-memory' MCP server when prompted."
