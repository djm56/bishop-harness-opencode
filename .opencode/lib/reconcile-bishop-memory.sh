#!/bin/sh
#
# reconcile-bishop-memory.sh
#
# INVOKED, NOT SOURCED. This script is the sole implementation of the mission-
# close reconciliation step (bishop.md closing step E / mission-lifecycle checklist
# item 10). Both doctrine files call this script by name instead of embedding
# the shell inline, so there is exactly one place to get the logic right and
# exactly one thing to test.
#
# Called by relative path, as documented in bishop.md closing step E and the
# mission-lifecycle checklist. A relative path is resolved by the CALLER'S
# shell against its current working directory before this script is ever
# reached — that resolution is not something this script can affect. The
# caller must invoke it from the project root.
#
# Once started, this script resolves ITS OWN location from $0 and derives an
# absolute project root from that, so the --root it goes on to pass down to
# reconcile-memory.py is correct regardless of the caller's cwd. That
# guarantee begins only after the script has been found and started — it is
# not a substitute for the caller being in the right place to begin with.
#
# Usage (from the project root):
#   .opencode/lib/reconcile-bishop-memory.sh
#
# Behavior:
#   - No .opencode/bishop-memory.conf next to the project root this script
#     lives under -> standalone default, nothing to reconcile, exit 0.
#   - Conf present but BISHOP_MEMORY_MODE is not "central" -> exit 0.
#   - Conf present and mode is "central" -> exec reconcile-memory.py from
#     BISHOP_MEMORY_HOME, passing --root (absolute), --harness (always, since
#     central mode requires it non-empty), and --url only when
#     BISHOP_MEMORY_URL is non-empty (never passed as an empty string, so the
#     reconciler's own default applies).
#
# Every failure prints one line to stderr naming exactly which precondition
# failed, then returns non-zero. Nothing here fails silently.
#
# Exit codes:
#   0   - skipped (standalone / no conf / mode not central) or the reconciler
#         ran and exited 0
#   2   - a precondition failed before the reconciler could be invoked
#         (missing/unreadable library, unparseable conf, missing required
#         variable, missing/unreadable reconciler script). Nothing was
#         compared; there are no entity counts to disagree on.
#   1 or  - propagated unchanged from reconcile-memory.py itself (this script
#   other   execs it as its last step, so its exit status becomes this
#          script's exit status). The reconciler ran and is reporting its
#          own failure — e.g. exit 1 for an entity-count mismatch, exit 66
#          for a bad --root. Never collides with 2, which this script
#          reserves for its own precondition failures.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" || {
  echo "reconcile-bishop-memory.sh: cannot resolve script directory from \$0=$0" >&2
  exit 2
}
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

CONF_FILE="$PROJECT_ROOT/.opencode/bishop-memory.conf"
CONF_LIB="$SCRIPT_DIR/bishop-memory-conf.sh"

# No conf at all: standalone is the default behavior, nothing to reconcile.
if [ ! -f "$CONF_FILE" ]; then
  exit 0
fi

if [ ! -f "$CONF_LIB" ]; then
  echo "reconcile-bishop-memory.sh: conf library not found at $CONF_LIB" >&2
  exit 2
fi
if [ ! -r "$CONF_LIB" ]; then
  echo "reconcile-bishop-memory.sh: conf library present but unreadable at $CONF_LIB" >&2
  exit 2
fi

. "$CONF_LIB" || {
  echo "reconcile-bishop-memory.sh: failed to source $CONF_LIB" >&2
  exit 2
}

bishop_memory_read_conf "$CONF_FILE" || {
  echo "reconcile-bishop-memory.sh: failed to parse $CONF_FILE" >&2
  exit 2
}

# Standalone, or an unrecognized/unset mode: nothing to reconcile.
if [ "$BISHOP_MEMORY_MODE" != "central" ]; then
  exit 0
fi

if [ -z "$BISHOP_HARNESS" ]; then
  echo "reconcile-bishop-memory.sh: BISHOP_HARNESS is empty in $CONF_FILE; required in central mode" >&2
  exit 2
fi

if [ -z "$BISHOP_MEMORY_HOME" ]; then
  echo "reconcile-bishop-memory.sh: BISHOP_MEMORY_HOME is empty in $CONF_FILE; required in central mode" >&2
  exit 2
fi

RECONCILER="$BISHOP_MEMORY_HOME/scripts/reconcile-memory.py"

if [ ! -f "$RECONCILER" ]; then
  echo "reconcile-bishop-memory.sh: reconciler not found at $RECONCILER" >&2
  exit 2
fi
if [ ! -r "$RECONCILER" ]; then
  echo "reconcile-bishop-memory.sh: reconciler present but unreadable at $RECONCILER" >&2
  exit 2
fi

if [ -n "$BISHOP_MEMORY_URL" ]; then
  exec "$RECONCILER" --root "$PROJECT_ROOT/.opencode/memory" --harness "$BISHOP_HARNESS" --url "$BISHOP_MEMORY_URL" "$@"
else
  exec "$RECONCILER" --root "$PROJECT_ROOT/.opencode/memory" --harness "$BISHOP_HARNESS" "$@"
fi
