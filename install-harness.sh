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
UPDATE=0

PORTABLE_ROOT_FILES=(
  "AGENTS.md"
  "SOUL.md"
  "CREW-MANIFEST.md"
  "opencode.json"
)

PORTABLE_OPCODE_DIR=".opencode"

EXCLUDE_LINES=(
  "/.opencode/"
  "/.opencode/qa.conf"
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
  --update    Refresh harness files in an existing install. Only files whose
              size or content differ are replaced (each one backed up to
              .bishop-backups/); memory, about/, local confs and opencode.json
              are never written. Combine with --dry-run for a report only.
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
    --update)
      UPDATE=1
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

if [[ "$UPDATE" -eq 1 && "$FORCE" -eq 1 ]]; then
  log "--update and --force cannot be combined. --update already replaces changed harness files."
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

  # The runtime layer (memory/, about/, bishop-memory.conf) belongs to the
  # source checkout and must never be copied; memory is seeded from the zip.
  if has_command rsync; then
    rsync -a --exclude='/memory/' --exclude='/about/' --exclude='/bishop-memory.conf' \
      "$src/" "$dst/"
  else
    local entry name
    for entry in "$src"/* "$src"/.[!.]*; do
      [[ -e "$entry" ]] || continue
      name="${entry##*/}"
      case "$name" in
        memory|about|bishop-memory.conf) continue ;;
      esac
      cp -R "$entry" "$dst/"
    done
  fi

  log "Copied portable .opencode/ -> $TARGET_DIR/"
}

# -----------------------------------------------------------------------------
# Memory seeding from memory.zip
#
# The seed must land at .opencode/memory/{state,missions,workspace,findings,
# reference}. memory.zip may or may not wrap its contents in a top-level
# memory/ folder, so it is extracted to a temp dir, normalised, and then placed
# file by file. Existing files are never overwritten unless --force is given.
# Memory counts as seeded only when state/CURRENT-MISSION.md exists; a bare or
# wrongly nested .opencode/memory/ does not.
# -----------------------------------------------------------------------------
SEED_TMP=""

cleanup_seed_tmp() {
  if [[ -n "$SEED_TMP" && -d "$SEED_TMP" ]]; then
    rm -rf "$SEED_TMP"
  fi
}
trap cleanup_seed_tmp EXIT

memory_is_seeded() {
  [[ -f "$1/state/CURRENT-MISSION.md" ]]
}

# True when the directory holds any state file other than .gitkeep.
has_state_files() {
  [[ -d "$1/state" ]] && [[ -n "$(find "$1/state" -type f ! -name '.gitkeep' 2>/dev/null | head -n 1)" ]]
}

# place_tree SRC DST MODE
#   MODE is one of:
#     seed   - copy files that are missing in DST; keep existing ones.
#     force  - copy every file, overwriting existing ones.
#     repair - move files that are missing in DST with mv -n; keep existing
#              ones; drop SRC copies that are identical to DST.
# Honours --dry-run by reporting the exact destination paths instead.
PLACE_CONFLICTS=0

place_tree() {
  local src="$1" dst="$2" mode="$3"
  local entry rel target

  while IFS= read -r -d '' entry; do
    rel="${entry#"$src"/}"
    target="$dst/$rel"
    if [[ ! -d "$target" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log_dry "would create directory $target/"
      else
        mkdir -p "$target"
      fi
    fi
  done < <(find "$src" -mindepth 1 -type d -print0)

  while IFS= read -r -d '' entry; do
    rel="${entry#"$src"/}"
    target="$dst/$rel"

    if [[ -e "$target" || -L "$target" ]]; then
      if cmp -s "$entry" "$target"; then
        if [[ "$mode" == "repair" ]]; then
          if [[ "$DRY_RUN" -eq 1 ]]; then
            log_dry "would remove nested duplicate $entry (identical to $target)"
          else
            rm -f "$entry"
            log "Removed nested duplicate $entry (identical to $target)"
          fi
        fi
        continue
      fi

      if [[ "$mode" == "force" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
          log_dry "would overwrite $target"
        else
          cp -p "$entry" "$target"
          log "Overwrote $target"
        fi
      else
        PLACE_CONFLICTS=$((PLACE_CONFLICTS + 1))
        if [[ "$mode" == "repair" ]]; then
          log "WARNING: left $entry in place; $target already exists and differs."
        else
          log "Kept existing $target (differs from seed)"
        fi
      fi
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      if [[ "$mode" == "repair" ]]; then
        log_dry "would move $entry -> $target"
      else
        log_dry "would create $target"
      fi
      continue
    fi

    mkdir -p "$(dirname "$target")"
    if [[ "$mode" == "repair" ]]; then
      mv -n "$entry" "$target"
      log "Moved $entry -> $target"
    else
      cp -p "$entry" "$target"
      log "Created $target"
    fi
  done < <(find "$src" -mindepth 1 \( -type f -o -type l \) -print0)
}

# Refuses when both the nested and the top-level memory copies hold state
# files. Runs as a preflight so nothing is copied before the refusal.
check_nested_memory_conflict() {
  local memdir="$TARGET_DIR/$PORTABLE_OPCODE_DIR/memory"
  local nested="$memdir/memory"

  if [[ -d "$nested" ]] && has_state_files "$nested" && has_state_files "$memdir"; then
    log "ERROR: both $nested/state and $memdir/state contain state files."
    log "       Refusing to merge them automatically. Decide which copy is live,"
    log "       move or archive the other by hand, then re-run the installer."
    exit 1
  fi
}

# Repairs .opencode/memory/memory/ left by earlier installers. Refuses when
# both the nested and the top-level copies hold state files.
repair_nested_memory() {
  local memdir="$1"
  local nested="$memdir/memory"

  [[ -d "$nested" ]] || return 0

  log "Found nested memory layout at $nested (from an earlier install)."
  check_nested_memory_conflict

  PLACE_CONFLICTS=0
  place_tree "$nested" "$memdir" repair

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_dry "would remove $nested once it is empty"
    return 0
  fi

  find "$nested" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true

  if [[ -d "$nested" ]]; then
    log "WARNING: $nested still holds $PLACE_CONFLICTS conflicting file(s); resolve them by hand."
  else
    log "Repaired nested memory layout; removed $nested"
  fi
}

extract_seed() {
  local zip="$1" dest="$2"

  if has_command unzip; then
    unzip -q "$zip" -d "$dest"
  elif has_command python3; then
    python3 - "$zip" "$dest" <<'PY'
import zipfile, sys
zip_path, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path, 'r') as z:
    z.extractall(dest)
PY
  else
    log "ERROR: Cannot extract memory.zip (unzip or python3 required)."
    exit 1
  fi

  rm -rf "$dest/__MACOSX"
}

# Prints the directory holding the seed folders, stripping a single top-level
# memory/ wrapper when that is the only thing in the archive.
seed_root() {
  local dir="$1"
  local entries
  entries="$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  if [[ "$entries" -eq 1 && -d "$dir/memory" ]]; then
    printf '%s\n' "$dir/memory"
  else
    printf '%s\n' "$dir"
  fi
}

seed_memory() {
  local zip="$SOURCE_DIR/$PORTABLE_OPCODE_DIR/memory.zip"
  local memdir="$TARGET_DIR/$PORTABLE_OPCODE_DIR/memory"
  local root mode

  repair_nested_memory "$memdir"

  if [[ ! -f "$zip" ]]; then
    log "No memory.zip found in source; skipping memory seeding."
    log "Create .opencode/memory/ manually from the templates if needed."
    return
  fi

  local seeded=0
  if memory_is_seeded "$memdir"; then
    seeded=1
  elif [[ "$DRY_RUN" -eq 1 ]] && memory_is_seeded "$memdir/memory"; then
    # In a dry run the repair above has not moved anything yet.
    seeded=1
  fi

  if [[ "$seeded" -eq 1 && "$FORCE" -ne 1 ]]; then
    log "Memory already seeded ($memdir/state/CURRENT-MISSION.md present); skipping. Use --force to re-seed."
    return
  fi

  if [[ "$seeded" -eq 0 && -d "$memdir" ]]; then
    log "$memdir exists but is not seeded (no state/CURRENT-MISSION.md); adding missing seed files."
  fi

  SEED_TMP="$(mktemp -d "${TMPDIR:-/tmp}/bishop-seed.XXXXXX")"
  extract_seed "$zip" "$SEED_TMP"
  root="$(seed_root "$SEED_TMP")"

  mode="seed"
  if [[ "$FORCE" -eq 1 ]]; then
    mode="force"
    log "--force: re-seeding memory. Seed files overwrite existing ones, including state files."
    if [[ -d "$memdir" ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log_dry "would back up $memdir first"
      else
        local backup="$memdir.bishop-backup-$(backup_timestamp)"
        cp -R "$memdir" "$backup"
        log "Backed up existing memory directory to $backup"
      fi
    fi
  fi

  if [[ "$DRY_RUN" -ne 1 ]]; then
    mkdir -p "$memdir"
  fi

  PLACE_CONFLICTS=0
  place_tree "$root" "$memdir" "$mode"

  if [[ "$DRY_RUN" -ne 1 ]]; then
    if memory_is_seeded "$memdir"; then
      log "Seeded $memdir from memory.zip"
    else
      log "ERROR: seeding finished but $memdir/state/CURRENT-MISSION.md is missing."
      exit 1
    fi
  fi
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
# Update mode
#
# Refreshes the harness-owned files (the root doctrine files and the portable
# .opencode/ layer) in a target that already has the harness installed. The
# runtime layer — memory/, about/, bishop-memory.conf, qa.conf and installed
# packages — is never read or written. A file is replaced only when its size
# differs or, at equal size, its bytes differ; each replaced file is backed up
# first. opencode.json is compared and reported but never written, because a
# target carries its own provider and MCP config in it. Files that exist only
# in the target are listed and left alone.
# -----------------------------------------------------------------------------
UPDATE_ROOT_FILES=(
  "AGENTS.md"
  "SOUL.md"
  "CREW-MANIFEST.md"
)

UPDATE_BACKUP_DIR="$TARGET_DIR/.bishop-backups/update-$(backup_timestamp)"
UPDATE_BACKED_UP=0
UPD_NEW=0
UPD_CHANGED=0
UPD_SAME=0
UPD_REVIEW=0
UPD_EXTRA=0

# Colour only when writing to a terminal, and never when NO_COLOR is set.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_NEW=$'\033[32m'
  C_CHANGED=$'\033[33m'
  C_REVIEW=$'\033[35m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_OFF=$'\033[0m'
else
  C_NEW="" C_CHANGED="" C_REVIEW="" C_DIM="" C_BOLD="" C_OFF=""
fi

file_size() {
  wc -c < "$1" | tr -d ' '
}

report_line() {
  local tag="$1" colour="$2" rel="$3" detail="${4:-}"
  printf '  %s%-8s%s %s %s%s%s\n' "$colour" "$tag" "$C_OFF" "$rel" "$C_DIM" "$detail" "$C_OFF"
}

# Prints the harness-owned files under the .opencode/ directory BASE, relative
# to BASE, sorted and NUL-separated.
list_harness_files() {
  local base="$1" f
  [[ -d "$base" ]] || return 0
  find "$base" \
    \( -path "$base/memory" -o -path "$base/about" -o -name node_modules -o -name '*.bishop-backup-*' \) -prune \
    -o -type f \
    ! -name '.DS_Store' \
    ! -path "$base/bishop-memory.conf" \
    ! -path "$base/qa.conf" \
    ! -path "$base/package.json" \
    ! -path "$base/package-lock.json" \
    ! -path "$base/bun.lock" \
    -print0 \
    | while IFS= read -r -d '' f; do printf '%s\0' "${f#"$base"/}"; done \
    | sort -z
}

backup_for_update() {
  local dst="$1" rel="$2"
  mkdir -p "$(dirname "$UPDATE_BACKUP_DIR/$rel")"
  cp -p "$dst" "$UPDATE_BACKUP_DIR/$rel"
  UPDATE_BACKED_UP=1
}

# update_file SRC DST REL — adds DST when missing, replaces it when it differs.
update_file() {
  local src="$1" dst="$2" rel="$3"
  local src_size dst_size detail

  if [[ -d "$dst" ]]; then
    UPD_REVIEW=$((UPD_REVIEW + 1))
    report_line REVIEW "$C_REVIEW" "$rel" "(a directory in the target; not touched)"
    return
  fi

  if [[ ! -e "$dst" ]]; then
    UPD_NEW=$((UPD_NEW + 1))
    report_line NEW "$C_NEW" "$rel" "($(file_size "$src") bytes)"
    if [[ "$DRY_RUN" -ne 1 ]]; then
      mkdir -p "$(dirname "$dst")"
      cp -p "$src" "$dst"
    fi
    return
  fi

  src_size="$(file_size "$src")"
  dst_size="$(file_size "$dst")"
  if [[ "$src_size" -ne "$dst_size" ]]; then
    detail="($dst_size -> $src_size bytes)"
  elif ! cmp -s "$src" "$dst"; then
    detail="(same size, content differs)"
  else
    UPD_SAME=$((UPD_SAME + 1))
    return
  fi

  UPD_CHANGED=$((UPD_CHANGED + 1))
  report_line CHANGED "$C_CHANGED" "$rel" "$detail"
  if [[ "$DRY_RUN" -ne 1 ]]; then
    backup_for_update "$dst" "$rel"
    cp -p "$src" "$dst"
  fi
}

# Compares the harness-owned keys of opencode.json and reports, never writes.
review_opencode_json() {
  local src="$SOURCE_DIR/opencode.json" dst="$TARGET_DIR/opencode.json"
  local diffs line

  [[ -f "$src" ]] || return 0

  if [[ ! -f "$dst" ]]; then
    UPD_REVIEW=$((UPD_REVIEW + 1))
    report_line REVIEW "$C_REVIEW" "opencode.json" "(missing in target; run the installer without --update to create it)"
    return
  fi

  if ! has_command python3; then
    if cmp -s "$src" "$dst"; then
      UPD_SAME=$((UPD_SAME + 1))
    else
      UPD_REVIEW=$((UPD_REVIEW + 1))
      report_line REVIEW "$C_REVIEW" "opencode.json" "(differs; python3 unavailable for a key-level compare)"
    fi
    return
  fi

  if ! diffs="$(python3 - "$src" "$dst" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    harness = json.load(f)
with open(sys.argv[2]) as f:
    target = json.load(f)

# Only the keys the harness owns; provider, model and mcp config stay with the target.
for key in ('default_agent', 'plugin', 'instructions', 'tools', 'agent'):
    if key not in harness:
        continue
    want, have = harness[key], target.get(key)
    if isinstance(want, dict) and isinstance(have, dict):
        for sub, value in want.items():
            if sub not in have:
                print(f"{key}.{sub}: missing in target")
            elif have[sub] != value:
                if isinstance(value, dict) and isinstance(have[sub], dict):
                    fields = sorted(k for k in set(value) | set(have[sub]) if value.get(k) != have[sub].get(k))
                    print(f"{key}.{sub}: differs ({', '.join(fields)})")
                else:
                    print(f"{key}.{sub}: differs")
    elif isinstance(want, list) and isinstance(have, list):
        for item in want:
            if item not in have:
                print(f"{key}: missing {item}")
    elif have != want:
        print(f"{key}: differs")
PY
)"; then
    UPD_REVIEW=$((UPD_REVIEW + 1))
    report_line REVIEW "$C_REVIEW" "opencode.json" "(could not be parsed as JSON)"
    return
  fi

  if [[ -z "$diffs" ]]; then
    UPD_SAME=$((UPD_SAME + 1))
    return
  fi

  UPD_REVIEW=$((UPD_REVIEW + 1))
  report_line REVIEW "$C_REVIEW" "opencode.json" "(not touched; merge these by hand)"
  while IFS= read -r line; do
    printf '             %s- %s%s\n' "$C_DIM" "$line" "$C_OFF"
  done <<< "$diffs"
}

# Adds the backup folder to .git/info/exclude once, so backups stay untracked.
exclude_update_backups() {
  local exclude="$TARGET_DIR/.git/info/exclude"
  [[ -d "$TARGET_DIR/.git" ]] || return 0
  if [[ -f "$exclude" ]] && grep -qxF '/.bishop-backups/' "$exclude"; then
    return 0
  fi
  mkdir -p "$(dirname "$exclude")"
  printf '\n# Bishop harness update backups\n/.bishop-backups/\n' >> "$exclude"
}

print_update_report() {
  local verb_new="added" verb_changed="replaced" heading="Update report"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    verb_new="would add"
    verb_changed="would replace"
    heading="Update report (dry run, nothing changed)"
  fi

  printf '\n%s%s%s  %s\n' "$C_BOLD" "$heading" "$C_OFF" "$TARGET_DIR"
  printf '  %s%-8s%s %4d  %s\n' "$C_NEW" NEW "$C_OFF" "$UPD_NEW" "$verb_new"
  printf '  %s%-8s%s %4d  %s\n' "$C_CHANGED" CHANGED "$C_OFF" "$UPD_CHANGED" "$verb_changed"
  printf '  %-8s %4d  %s\n' SAME "$UPD_SAME" "unchanged"
  printf '  %s%-8s%s %4d  %s\n' "$C_REVIEW" REVIEW "$C_OFF" "$UPD_REVIEW" "needs a human look; not touched"
  printf '  %-8s %4d  %s\n' EXTRA "$UPD_EXTRA" "in target only; left alone"

  if [[ "$UPD_CHANGED" -gt 0 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '  %sBackups would go to %s%s\n' "$C_DIM" "$UPDATE_BACKUP_DIR" "$C_OFF"
    elif [[ "$UPDATE_BACKED_UP" -eq 1 ]]; then
      printf '  %sBackups of replaced files: %s%s\n' "$C_DIM" "$UPDATE_BACKUP_DIR" "$C_OFF"
    fi
  fi
  printf '  %sNever touched: .opencode/memory/, .opencode/about/, bishop-memory.conf, qa.conf, node_modules/%s\n' "$C_DIM" "$C_OFF"
}

run_update() {
  local src_oc="$SOURCE_DIR/$PORTABLE_OPCODE_DIR"
  local dst_oc="$TARGET_DIR/$PORTABLE_OPCODE_DIR"
  local file rel

  if [[ "$TARGET_DIR" == "$SOURCE_DIR" ]]; then
    log "Target is the harness source itself; nothing to update."
    exit 1
  fi

  if [[ ! -d "$dst_oc" || ! -f "$TARGET_DIR/AGENTS.md" ]]; then
    log "No installed harness found in $TARGET_DIR (expected AGENTS.md and .opencode/)."
    log "Run the installer without --update to install it first."
    exit 1
  fi

  log "Updating Bishop harness files in $TARGET_DIR"
  echo

  for file in "${UPDATE_ROOT_FILES[@]}"; do
    [[ -f "$SOURCE_DIR/$file" ]] || continue
    update_file "$SOURCE_DIR/$file" "$TARGET_DIR/$file" "$file"
  done
  review_opencode_json

  while IFS= read -r -d '' rel; do
    update_file "$src_oc/$rel" "$dst_oc/$rel" "$PORTABLE_OPCODE_DIR/$rel"
  done < <(list_harness_files "$src_oc")

  while IFS= read -r -d '' rel; do
    if [[ ! -e "$src_oc/$rel" ]]; then
      UPD_EXTRA=$((UPD_EXTRA + 1))
      report_line EXTRA "$C_DIM" "$PORTABLE_OPCODE_DIR/$rel" "(not in harness source)"
    fi
  done < <(list_harness_files "$dst_oc")

  if [[ "$DRY_RUN" -ne 1 && "$UPDATE_BACKED_UP" -eq 1 ]]; then
    exclude_update_backups
  fi

  print_update_report
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  if [[ "$UPDATE" -eq 1 ]]; then
    run_update
    return
  fi

  log "Installing Bishop harness into $TARGET_DIR"

  check_nested_memory_conflict
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
