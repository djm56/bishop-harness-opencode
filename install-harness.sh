#!/usr/bin/env bash
# install-harness.sh
# Installs the Bishop opencode harness into a target project.

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR=""
DRY_RUN=0
FORCE=0

PORTABLE_ROOT_FILES=(
  "AGENTS.md"
  "SOUL.md"
  "CREW-MANIFEST.md"
  "opencode.json"
)

PORTABLE_OPCODE_DIR=".opencode"

EXCLUDE_LINES=(
  "/.opencode/"
  "/AGENTS.md"
  "/SOUL.md"
  "/CREW-MANIFEST.md"
  "/opencode.json"
)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] /path/to/target-project

Install the Bishop opencode harness into a target project.

Options:
  --dry-run   Show what would happen without making changes.
  --force     Overwrite existing harness files and re-seed memory.
  --help      Show this help message.
EOF
}

log() {
  printf '[bishop-harness] %s\n' "$*"
}

log_dry() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[bishop-harness] DRY-RUN: %s\n' "$*"
  fi
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

backup_timestamp() {
  date +%Y%m%d-%H%M%S
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      log "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -n "${TARGET_DIR:-}" ]]; then
        log "Only one target directory is allowed."
        usage
        exit 1
      fi
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

if [[ -z "${TARGET_DIR:-}" ]]; then
  log "No target directory provided."
  usage
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  log "Target directory does not exist: $TARGET_DIR"
  exit 1
fi

# Resolve absolute paths so later operations are unambiguous.
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# -----------------------------------------------------------------------------
# Portable root files
# -----------------------------------------------------------------------------
copy_root_files() {
  for file in "${PORTABLE_ROOT_FILES[@]}"; do
    local src="$SOURCE_DIR/$file"
    local dst="$TARGET_DIR/$file"

    if [[ ! -e "$src" ]]; then
      log "Skipping missing portable file: $file"
      continue
    fi

    if [[ "$file" == "opencode.json" ]]; then
      install_opencode_json "$src" "$dst"
      continue
    fi

    if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
      log "Already exists (skipping): $dst"
      log_dry "would skip existing root file $file"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_dry "would copy $file -> $TARGET_DIR/"
      continue
    fi

    if [[ "$FORCE" -eq 1 && -e "$dst" ]]; then
      local backup="$dst.bishop-backup-$(backup_timestamp)"
      cp "$dst" "$backup"
      log "Backed up existing file to $backup"
    fi

    cp "$src" "$dst"
    log "Copied $file -> $TARGET_DIR/"
  done
}

# -----------------------------------------------------------------------------
# opencode.json handling
#
# If the target already has an opencode.json we merge the harness agent block
# and instructions so we do not clobber provider keys or other project config.
# If --force is passed we back up the existing file and copy the portable one.
# -----------------------------------------------------------------------------
install_opencode_json() {
  local src="$1"
  local dst="$2"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
      log_dry "would merge $src into existing $dst"
    else
      log_dry "would copy $src -> $dst"
    fi
    return
  fi

  if [[ -e "$dst" && "$FORCE" -eq 1 ]]; then
    local backup="$dst.bishop-backup-$(backup_timestamp)"
    cp "$dst" "$backup"
    log "Backed up existing opencode.json to $backup"
    cp "$src" "$dst"
    log "Copied opencode.json -> $TARGET_DIR/ (forced)"
    return
  fi

  if [[ -e "$dst" ]]; then
    if has_command python3; then
      python3 - "$src" "$dst" <<'PY'
import json, sys
src_path, dst_path = sys.argv[1], sys.argv[2]
with open(src_path) as f:
    portable = json.load(f)
with open(dst_path) as f:
    target = json.load(f)

# Ensure SOUL.md is in the global instructions.
target.setdefault('instructions', [])
if './SOUL.md' not in target['instructions']:
    target['instructions'].append('./SOUL.md')

# Merge agent definitions; do not overwrite existing agents.
target.setdefault('agent', {})
for key, value in portable.get('agent', {}).items():
    if key not in target['agent']:
        target['agent'][key] = value

# Only set the default agent if the target has none.
if not target.get('default_agent'):
    target['default_agent'] = portable.get('default_agent', 'bishop')

with open(dst_path, 'w') as f:
    json.dump(target, f, indent=2)
    f.write('\n')
PY
      log "Merged harness agents into existing opencode.json"
    else
      log "WARNING: $dst already exists and python3 is not available."
      log "         Merge the harness 'agent' block from $src manually."
    fi
    return
  fi

  cp "$src" "$dst"
  log "Copied opencode.json -> $TARGET_DIR/"
}

# -----------------------------------------------------------------------------
# .opencode/ portable layer
# -----------------------------------------------------------------------------
copy_opcode_dir() {
  local src="$SOURCE_DIR/$PORTABLE_OPCODE_DIR"
  local dst="$TARGET_DIR/$PORTABLE_OPCODE_DIR"

  if [[ ! -d "$src" ]]; then
    log "Portable .opencode/ directory not found; skipping."
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "would copy $PORTABLE_OPCODE_DIR/ -> $TARGET_DIR/"
    return
  fi

  if [[ "$FORCE" -eq 1 && -d "$dst" ]]; then
    local backup="$dst.bishop-backup-$(backup_timestamp)"
    cp -R "$dst" "$backup"
    log "Backed up existing .opencode/ to $backup"
  fi

  mkdir -p "$dst"

  if has_command rsync; then
    rsync -a --exclude='memory/' --exclude='about/' --exclude='bishop-memory.conf' \
      "$src/" "$dst/"
  else
    cp -R "$src/"* "$dst/" 2>/dev/null || true
  fi

  log "Copied portable .opencode/ -> $TARGET_DIR/"
}

# -----------------------------------------------------------------------------
# Memory seeding from memory.zip
# -----------------------------------------------------------------------------
seed_memory() {
  local zip="$SOURCE_DIR/$PORTABLE_OPCODE_DIR/memory.zip"
  local memdir="$TARGET_DIR/$PORTABLE_OPCODE_DIR/memory"

  if [[ ! -f "$zip" ]]; then
    log "No memory.zip found in source; skipping memory seeding."
    log "Create .opencode/memory/ manually from the templates if needed."
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -d "$memdir" && "$FORCE" -ne 1 ]]; then
      log_dry "would skip memory seeding because $memdir exists"
    else
      log_dry "would extract $zip -> $memdir/"
    fi
    return
  fi

  if [[ -d "$memdir" && "$FORCE" -ne 1 ]]; then
    log "Memory directory already exists; skipping seeding. Use --force to re-seed."
    return
  fi

  if [[ "$FORCE" -eq 1 && -d "$memdir" ]]; then
    local backup="$memdir.bishop-backup-$(backup_timestamp)"
    cp -R "$memdir" "$backup"
    log "Backed up existing memory directory to $backup"
  fi

  mkdir -p "$memdir"

  if has_command unzip; then
    unzip -q "$zip" -d "$memdir"
  elif has_command python3; then
    python3 - "$zip" "$memdir" <<'PY'
import zipfile, sys
zip_path, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path, 'r') as z:
    z.extractall(dest)
PY
  else
    log "ERROR: Cannot extract memory.zip (unzip or python3 required)."
    exit 1
  fi

  log "Seeded .opencode/memory/ from memory.zip"
}

# -----------------------------------------------------------------------------
# Git exclude
# -----------------------------------------------------------------------------
update_git_exclude() {
  local exclude="$TARGET_DIR/.git/info/exclude"

  if [[ ! -d "$TARGET_DIR/.git" ]]; then
    log "Target is not a git repository; skipping .git/info/exclude update."
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "would update $exclude with harness untrack rules"
    return
  fi

  mkdir -p "$(dirname "$exclude")"

  # Add a marker block so we can identify our entries later.
  {
    echo ""
    echo "# Bishop harness runtime files (not part of the product repo)"
    for line in "${EXCLUDE_LINES[@]}"; do
      echo "$line"
    done
  } >> "$exclude"

  log "Updated .git/info/exclude with harness untrack rules"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  log "Installing Bishop harness into $TARGET_DIR"

  copy_root_files
  copy_opcode_dir
  seed_memory
  update_git_exclude

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry run complete. No changes were made."
  else
    log "Install complete."
    log "Next: open $TARGET_DIR in opencode and start a mission with bishop."
  fi
}

main "$@"
