#!/bin/sh
#
# bishop-memory-conf.sh
#
# SOURCED ONLY — this file is never executed directly. It exports a single
# function to be called after sourcing.
#
# Shared POSIX sh function to parse .opencode/bishop-memory.conf
#
# Usage:
#   . /path/to/.opencode/lib/bishop-memory-conf.sh
#   bishop_memory_read_conf /path/to/.opencode/bishop-memory.conf
#   if [ $? -eq 0 ]; then
#     echo "Mode: $BISHOP_MEMORY_MODE"
#   fi
#
# On success, returns 0 and sets these output variables:
#   BISHOP_MEMORY_MODE
#   BISHOP_MEMORY_URL
#   BISHOP_HARNESS
#   BISHOP_MEMORY_HOME
#
# On failure (file missing or unreadable), returns 1 and variables remain unchanged.
#
# NOTE: This function uses POSIX sh, which has no local keyword. The following
# variables persist in the caller's shell after the function returns:
#   _CONF_PATH
#   _CONFIG_LINE
#   _CONFIG_KEY
#   _CONFIG_VALUE
# Callers must avoid reusing these names; the underscore prefix marks them reserved.
#
# Parsing rules:
#   - Read line by line with IFS= read -r (no backslash interpretation)
#   - Skip blank lines and lines starting with #
#   - Split on the FIRST = only
#   - No whitespace trimming of key or value
#   - No quote stripping
#   - No inline trailing-comment stripping
#   - Unrecognized keys ignored
#   - Last occurrence of a repeated key wins
#
# Known limitation (same as pre-refactor):
#   A final line without a trailing newline is skipped by read and not processed.
#   Always ensure conf files end with a newline. This behavior matches the
#   original inline implementation and is retained to preserve the grammar.
#

bishop_memory_read_conf() {
  # $1 = path to conf file
  _CONF_PATH="$1"

  # Initialize all four variables to empty
  BISHOP_MEMORY_MODE=""
  BISHOP_MEMORY_URL=""
  BISHOP_HARNESS=""
  BISHOP_MEMORY_HOME=""

  # Try to read the file. If it fails, return 1 silently.
  if ! [ -f "$_CONF_PATH" ]; then
    return 1
  fi

  while IFS= read -r _CONFIG_LINE; do
    # Skip blank lines and comment lines
    case "$_CONFIG_LINE" in
      "") continue ;;
      \#*) continue ;;
    esac

    # Split on the FIRST = only
    _CONFIG_KEY="${_CONFIG_LINE%%=*}"
    _CONFIG_VALUE="${_CONFIG_LINE#*=}"

    # Match and assign recognized keys
    case "$_CONFIG_KEY" in
      BISHOP_MEMORY_MODE)
        BISHOP_MEMORY_MODE="$_CONFIG_VALUE"
        ;;
      BISHOP_MEMORY_URL)
        BISHOP_MEMORY_URL="$_CONFIG_VALUE"
        ;;
      BISHOP_HARNESS)
        BISHOP_HARNESS="$_CONFIG_VALUE"
        ;;
      BISHOP_MEMORY_HOME)
        BISHOP_MEMORY_HOME="$_CONFIG_VALUE"
        ;;
    esac
  done < "$_CONF_PATH" 2>/dev/null || return 1

  return 0
}
