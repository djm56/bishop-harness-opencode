import { existsSync, readFileSync } from "fs"

/**
 * mission-guard.ts
 *
 * Opencode plugin port of the original bishop-harness hooks:
 * - completion-gate.sh -> tool.execute.before (hard block)
 * - state-continuity.sh -> tool.execute.after (advisory warnings)
 *
 * Exports EXACTLY ONE factory (`missionGuard`).
 *
 * WARNING: opencode's plugin loader treats every export of a plugin module as a
 * factory. Any extra export (helper, type, constant) will be called as a factory
 * and can silently break the session. Keep helpers private to this file.
 */

// Local plugin-shape types so this file type-checks without the private
// @opencode-ai/plugin package installed in the harness repo.
interface PluginInput {
  directory?: string
  worktree?: string
  [key: string]: unknown
}

type Plugin = (
  ctx: PluginInput
) => Promise<{ [hookName: string]: (...args: any[]) => any }>

// -----------------------------------------------------------------------------
// Defensive file I/O
// -----------------------------------------------------------------------------

/**
 * Read a UTF-8 file defensively.
 *
 * Opencode's runtime fs shim can return `undefined` for missing or sandboxed
 * files instead of throwing. This helper normalizes those cases to `undefined`
 * so callers can treat them as "file missing".
 *
 * @param filePath - Absolute path to the file.
 * @returns The file contents as a string, or `undefined` if unreadable.
 */
function readUtf8File(filePath: string): string | undefined {
  try {
    const result = readFileSync(filePath, "utf-8")
    return typeof result === "string" ? result : undefined
  } catch {
    return undefined
  }
}

/**
 * Resolve the project root from plugin context or a file path.
 *
 * PRIMARY: ctx.directory or ctx.worktree if provided by opencode.
 * SECONDARY: derive from an absolute path containing the memory tree.
 * FALLBACK: process.cwd().
 */
function resolveProjectRoot(
  ctx: PluginInput,
  filePath: string | undefined
): string {
  if (ctx?.directory) {
    return ctx.directory.replace(/\/$/, "")
  }
  if (ctx?.worktree) {
    return ctx.worktree.replace(/\/$/, "")
  }

  if (typeof filePath === "string" && filePath.includes(".opencode/memory/")) {
    const parts = filePath.split(".opencode/memory/")
    if (parts[0]) {
      return parts[0].replace(/\/$/, "")
    }
  }

  return process.cwd()
}

// -----------------------------------------------------------------------------
// Tool-argument extraction
// -----------------------------------------------------------------------------

interface FilePathAndContent {
  filePath: string
  content: string
}

/**
 * Extract filePath and content/newString from tool arguments across the
 * different shapes used by Write and Edit tools.
 *
 * Returns `null` when either cannot be found so the caller can fail open.
 */
function extractFilePathAndContent(args: any): FilePathAndContent | null {
  const filePath =
    args?.filePath || args?.path || args?.file || args?.file_path || null
  const content =
    args?.content ||
    args?.newString ||
    args?.new_string ||
    args?.replacement ||
    null

  if (!filePath || !content) {
    return null
  }

  return {
    filePath: String(filePath),
    content: String(content),
  }
}

// -----------------------------------------------------------------------------
// Mission ID parsing
// -----------------------------------------------------------------------------

/**
 * Extract a mission ID from markdown content.
 *
 * Matches lines mentioning "Mission ID" and returns the first
 * `mission-<token>` value. Tolerates field-list and table-row shapes.
 *
 * @param content - Markdown text to parse.
 * @returns The mission ID or `null` if none found.
 */
function parseMissionID(content: string): string | null {
  if (typeof content !== "string") return null
  const match = content.match(
    /Mission\s*ID\s*[|:]\s*(mission-[0-9a-zA-Z_-]+)/i
  )
  return match ? match[1] : null
}

/**
 * Extract the Status value from CURRENT-MISSION.md content.
 *
 * Matches "- Status: <value>" field-list shape (and tolerates table shape).
 * Returns one of not-started | in-progress | blocked | complete, or null.
 *
 * @param content - Markdown text to parse.
 * @returns The status value or `null` if none found.
 */
function parseMissionStatus(content: string): string | null {
  if (typeof content !== "string") return null
  const match = content.match(
    /Status\s*[|:]\s*(not-started|in-progress|blocked|complete)\b/i
  )
  return match ? match[1].toLowerCase() : null
}

/**
 * Extract the Mission ID column from a FLIGHT-RECORDER.md data row.
 *
 * Schema: | Timestamp | Mission ID | Step | Agent | Event | Note |
 * Column index 2 (after the empty leading split) is the mission ID.
 */
function parseRowMissionID(row: string): string | null {
  const columns = row.split("|").map((cell) => cell.trim())
  const value = columns[2]
  if (!value) return null
  const match = value.match(/^(mission-[0-9a-zA-Z_-]+)$/)
  return match ? match[1] : null
}

/**
 * Extract the Step column from a FLIGHT-RECORDER.md data row.
 *
 * Schema: | Timestamp | Mission ID | Step | Agent | Event | Note |
 * Column index 3 is the step.
 */
function parseRowStep(row: string): string | null {
  const columns = row.split("|").map((cell) => cell.trim())
  const value = columns[3]
  return value ?? null
}

/**
 * Extract the Timestamp column from a FLIGHT-RECORDER.md data row.
 *
 * Schema: | Timestamp | Mission ID | Step | Agent | Event | Note |
 * Column index 1 is the timestamp.
 */
function parseRowTimestamp(row: string): string | null {
  const columns = row.split("|").map((cell) => cell.trim())
  const value = columns[1]
  return value ?? null
}

// -----------------------------------------------------------------------------
// Completion-gate helpers
// -----------------------------------------------------------------------------

/**
 * Detect whether content is setting CURRENT-MISSION.md Status to "complete".
 *
 * Matches:
 * - "- Status: complete" or "| Status | complete |" style rows.
 * - A bare replacement string of exactly "complete" (with optional whitespace).
 *
 * Word boundary prevents matching "incomplete".
 */
function isSettingStatusComplete(content: string): boolean {
  if (/Status\s*[|:]\s*\bcomplete\b/im.test(content)) {
    return true
  }
  return /^\s*complete\s*$/i.test(content)
}

/**
 * Result codes for mandatory-debrief-section checks.
 */
const SECTION_OK = 0
const SECTION_MISSING = 1
const SECTION_UNDERPOPULATED = 2
const SECTION_INDETERMINATE = 3

/**
 * Check a named DEBRIEF.md section for a populated table.
 *
 * The section must exist and contain at least 3 lines beginning with "|"
 * (header, separator, and at least one data row).
 *
 * @param debriefContent - Full DEBRIEF.md contents.
 * @param headingPattern - Regex matching the section heading line.
 * @returns SECTION_OK, SECTION_MISSING, SECTION_UNDERPOPULATED, or SECTION_INDETERMINATE.
 */
function checkDebriefSection(
  debriefContent: string,
  headingPattern: RegExp
): number {
  try {
    const lines = debriefContent.split("\n")
    let inside = false
    let pipeCount = 0

    for (const line of lines) {
      if (headingPattern.test(line)) {
        inside = true
        continue
      }
      if (inside && /^##\s/.test(line)) {
        // Next top-level heading ends the section.
        break
      }
      if (inside && line.startsWith("|")) {
        pipeCount++
      }
    }

    if (pipeCount === 0) {
      return SECTION_MISSING
    }
    if (pipeCount < 3) {
      return SECTION_UNDERPOPULATED
    }
    return SECTION_OK
  } catch {
    return SECTION_INDETERMINATE
  }
}

// -----------------------------------------------------------------------------
// Flight-recorder helpers
// -----------------------------------------------------------------------------

/**
 * Return all data rows from a FLIGHT-RECORDER.md markdown table.
 *
 * Skips the header row (contains "Timestamp") and the separator row
 * (contains "---").
 */
function getFlightRecorderDataRows(content: string): string[] {
  if (typeof content !== "string") return []
  return content
    .split("\n")
    .filter(
      (line) =>
        line.startsWith("|") &&
        !line.includes("---") &&
        !line.includes("Timestamp")
    )
}

/**
 * Validate the newest FLIGHT-RECORDER.md data row structurally.
 *
 * Checks:
 * - leading and trailing pipes
 * - exactly 6 cells (7 pipes) after ignoring escaped \|
 * - timestamp format YYYY-MM-DD HH:MM UTC
 * - timestamp not earlier than the row above
 *
 * @param row - Newest data row.
 * @param previousRow - Second-newest data row, if any.
 * @returns Array of human-readable error messages.
 */
function validateFlightRecorderRow(
  row: string,
  previousRow: string | null
): string[] {
  const errors: string[] = []

  if (!/^\|.*\|$/.test(row)) {
    errors.push("row must begin with | and end with |")
  }

  // Count pipes after removing escaped pipes (\|).
  const pipeCount = row.replace(/\\\|/g, "").split("|").length - 1
  if (pipeCount !== 7) {
    errors.push(`row has ${pipeCount - 1} cells but should have 6`)
  }

  const timestamp = parseRowTimestamp(row)
  if (!timestamp || !/^\d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC$/.test(timestamp)) {
    errors.push("timestamp format is invalid (expected YYYY-MM-DD HH:MM UTC)")
  }

  if (previousRow && timestamp) {
    const prevTimestamp = parseRowTimestamp(previousRow)
    if (prevTimestamp && timestamp !== prevTimestamp && timestamp < prevTimestamp) {
      errors.push("timestamp is earlier than the previous row")
    }
  }

  return errors
}

/**
 * Find the last PROGRESS.md row whose Status column is "done" and return
 * its Step column.
 */
function findLastDoneStep(progressContent: string): string | null {
  const lines = progressContent.split("\n")
  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i]
    if (/^\|[^|]+\|[^|]+\|[^|]+\|\s*done\s*\|/i.test(line)) {
      const columns = line.split("|").map((cell) => cell.trim())
      return columns[1] ?? null
    }
  }
  return null
}

// -----------------------------------------------------------------------------
// Bishop-memory central-mode integration
// -----------------------------------------------------------------------------

interface BishopMemoryConf {
  mode: string
  url: string
  harness: string
}

/**
 * Parse `.opencode/bishop-memory.conf` using the same grammar as the POSIX sh
 * parser in `.opencode/lib/bishop-memory-conf.sh`.
 *
 * Rules:
 * - Skip blank lines and lines starting with `#`.
 * - Split on the FIRST `=` only.
 * - No trimming of keys or values.
 * - No quote stripping.
 * - Last occurrence of a repeated key wins.
 *
 * Missing or unreadable conf files return standalone defaults, so this function
 * never throws and central mode is never enabled by accident.
 *
 * @param projectRoot - Absolute path to the project root.
 * @returns Parsed bishop-memory configuration.
 */
function parseBishopMemoryConf(projectRoot: string): BishopMemoryConf {
  const defaults: BishopMemoryConf = {
    mode: "standalone",
    url: "",
    harness: "",
  }

  const content = readUtf8File(
    `${projectRoot}/.opencode/bishop-memory.conf`
  )
  if (!content) {
    return defaults
  }

  const result: BishopMemoryConf = { ...defaults }
  for (const line of content.split("\n")) {
    if (line === "" || line.startsWith("#")) {
      continue
    }

    const eq = line.indexOf("=")
    if (eq === -1) {
      continue
    }

    const key = line.slice(0, eq)
    const value = line.slice(eq + 1)

    if (key === "BISHOP_MEMORY_MODE") {
      result.mode = value
    } else if (key === "BISHOP_MEMORY_URL") {
      result.url = value
    } else if (key === "BISHOP_HARNESS") {
      result.harness = value
    }
  }

  return result
}

/**
 * Determine whether central-mode mirroring is enabled.
 *
 * Both `BISHOP_MEMORY_MODE=central` and a non-empty `BISHOP_MEMORY_URL` are
 * required. A missing harness name is tolerated here because the mirror is
 * advisory; the identity simply omits the harness prefix when absent.
 *
 * @param conf - Parsed bishop-memory configuration.
 * @returns True if central mode is configured.
 */
function isCentralModeEnabled(conf: BishopMemoryConf): boolean {
  return conf.mode === "central" && conf.url.length > 0
}

/**
 * Split a FLIGHT-RECORDER.md table row into cells, honouring escaped pipes.
 *
 * A backslash-pipe (`\|`) is treated as a literal pipe inside a cell, not a
 * column boundary. The source POSIX parser uses the same masking trick.
 *
 * @param row - A single table row beginning and ending with `|`.
 * @returns Array of cell values, trimmed.
 */
function splitFlightRecorderRow(row: string): string[] {
  const placeholder = "\u0000"
  const masked = row.replace(/\\\|/g, placeholder)
  return masked.split("|").map((cell) =>
    cell.replace(new RegExp(placeholder, "g"), "|").trim()
  )
}

/**
 * Extract the Agent column from a FLIGHT-RECORDER.md row, respecting escaped pipes.
 *
 * @param row - Raw table row.
 * @returns Trimmed agent value, or null if absent.
 */
function parseRowAgentEscaped(row: string): string | null {
  const columns = splitFlightRecorderRow(row)
  return columns[4] ?? null
}

/**
 * Extract the Event column from a FLIGHT-RECORDER.md row, respecting escaped pipes.
 *
 * @param row - Raw table row.
 * @returns Trimmed event value, or null if absent.
 */
function parseRowEventEscaped(row: string): string | null {
  const columns = splitFlightRecorderRow(row)
  return columns[5] ?? null
}

/**
 * Extract the Note column from a FLIGHT-RECORDER.md row, respecting escaped pipes.
 *
 * @param row - Raw table row.
 * @returns Trimmed note value, or null if absent.
 */
function parseRowNoteEscaped(row: string): string | null {
  const columns = splitFlightRecorderRow(row)
  return columns[6] ?? null
}

/**
 * Compute a lightweight checksum for a flight-recorder row.
 *
 * Used for in-memory deduplication so the same row is not mirrored twice in a
 * session. djb2 is chosen for its simplicity; cryptographic strength is not
 * required here.
 *
 * @param row - Raw flight-recorder row.
 * @returns Unsigned 32-bit checksum as a decimal string.
 */
function rowChecksum(row: string): string {
  let hash = 5381
  for (let i = 0; i < row.length; i++) {
    hash = (hash << 5) + hash + row.charCodeAt(i)
  }
  return String(hash >>> 0)
}

/**
 * Mirror a single FLIGHT-RECORDER.md row to the bishop-memory events endpoint.
 *
 * This is fire-and-forget: any network, timeout, or HTTP error is swallowed.
 * The function never writes local state, never blocks, and never throws.
 *
 * Mapping to `POST /v1/events` (see `bishop-memory/internal/model/event.go`):
 * - `task_id`    -> Mission ID
 * - `event_type` -> Event (max 64 characters)
 * - `summary`    -> Note (max 2000 characters)
 * - `agent`      -> `<BISHOP_HARNESS>:<Agent>` when both parts are present
 *
 * The endpoint is provisional per operator decision Q8 in task-20260916-01
 * CONTEXT.md: the source hook's `/v1/flight-recorder` path was never registered
 * by memoryd, so the mirror targets the real `POST /v1/events` endpoint instead.
 *
 * @param row - Newest validated FLIGHT-RECORDER.md data row.
 * @param conf - Parsed bishop-memory configuration.
 */
function mirrorFlightRecorderRow(row: string, conf: BishopMemoryConf): void {
  try {
    const mission = parseRowMissionID(row) || undefined
    const rawAgent = parseRowAgentEscaped(row)
    const event = parseRowEventEscaped(row)
    const note = parseRowNoteEscaped(row)

    // Skip rows that do not carry enough information to be useful events.
    if (!event || event === "—" || !note || note === "—") {
      return
    }

    // Hard caps from internal/model/event.go.
    const cappedEvent = event.length > 64 ? event.slice(0, 64) : event
    const cappedNote = note.length > 2000 ? note.slice(0, 2000) : note

    const composedAgent =
      conf.harness && rawAgent && rawAgent !== "—" && rawAgent !== "-"
        ? `${conf.harness}:${rawAgent}`
        : rawAgent || undefined

    // If the composed identity exceeds the model's cap, mirror without it
    // rather than sending a record that will be rejected.
    const agent =
      composedAgent && composedAgent.length <= 64 ? composedAgent : undefined

    const body: Record<string, string> = {
      event_type: cappedEvent,
      summary: cappedNote,
    }
    if (mission) {
      body.task_id = mission
    }
    if (agent) {
      body.agent = agent
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 2000)

    fetch(`${conf.url.replace(/\/$/, "")}/v1/events`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    })
      .then(() => {
        clearTimeout(timeout)
        // Advisory mirror: do not warn on non-2xx responses.
      })
      .catch(() => {
        clearTimeout(timeout)
        // Advisory mirror: failures are silent by design.
      })
  } catch {
    // Fail open: central mode must never break the local loop.
  }
}

// -----------------------------------------------------------------------------
// Plugin factory
// -----------------------------------------------------------------------------


export const missionGuard: Plugin = async (ctx: PluginInput) => {
  // In-memory checksum of the last flight-recorder row mirrored to the
  // bishop-memory service. Per-session deduplication is enough because the
  // mirror is advisory and never writes local pending state.
  let lastMirroredChecksum = ""

  return {
    /**
     * tool.execute.before: COMPLETION GATE
     *
     * Blocks Write/Edit attempts that set CURRENT-MISSION.md Status to complete
     * unless the mission's DEBRIEF.md exists and contains both mandatory
     * sections ("Wrong Assumptions" and "Sub-Agent Mistakes") with at least
     * three pipe-prefixed lines each.
     *
     * Fails open on any parsing error, missing tooling, or unreadable file.
     */
    "tool.execute.before": async (_input: any, output: any) => {
      let shouldBlock = false
      let reason = ""

      try {
        const args = output?.args
        if (!args) {
          return
        }

        const extracted = extractFilePathAndContent(args)
        if (!extracted) {
          return
        }

        const { filePath, content } = extracted
        const basename = filePath.split("/").pop()
        if (basename !== "CURRENT-MISSION.md") {
          return
        }

        if (!isSettingStatusComplete(content)) {
          return
        }

        const projectRoot = resolveProjectRoot(ctx, filePath)

        // Try to read the mission ID from the incoming content first; fall back
        // to the CURRENT-MISSION.md file on disk for bare "complete" edits.
        let missionID = parseMissionID(content)
        if (!missionID) {
          const currentMissionPath = `${projectRoot}/.opencode/memory/state/CURRENT-MISSION.md`
          if (existsSync(currentMissionPath)) {
            const currentContent = readUtf8File(currentMissionPath)
            missionID = currentContent ? parseMissionID(currentContent) : null
          }
        }
        if (!missionID) {
          return
        }

        const debriefPath = `${projectRoot}/.opencode/memory/missions/${missionID}/DEBRIEF.md`

        // DEBRIEF.md must exist.
        if (!existsSync(debriefPath)) {
          shouldBlock = true
          reason = `Completion gate: DEBRIEF.md missing for ${missionID}. Create it before marking the mission complete.`
        } else {
          // File exists. If we cannot read it, fail open rather than lock the loop.
          const debriefContent = readUtf8File(debriefPath)
          if (debriefContent === undefined) {
            return
          }

          const sections: Array<{ display: string; pattern: RegExp }> = [
            {
              display: "Wrong Assumptions",
              pattern: /^##\s*Wrong Assumptions\b/m,
            },
            {
              display: "Sub-Agent Mistakes",
              pattern: /^##\s*Sub-Agent Mistakes\b/m,
            },
          ]

          for (const section of sections) {
            const rc = checkDebriefSection(debriefContent, section.pattern)
            if (rc === SECTION_MISSING) {
              shouldBlock = true
              reason = `Completion gate: DEBRIEF.md for ${missionID} is missing the '${section.display}' section.`
              break
            } else if (rc === SECTION_UNDERPOPULATED) {
              shouldBlock = true
              reason = `Completion gate: DEBRIEF.md for ${missionID} has a '${section.display}' section but it is empty (fewer than 3 table rows).`
              break
            } else if (rc === SECTION_INDETERMINATE) {
              // Could not complete the check — fail open.
              return
            }
          }
        }
      } catch {
        // Any unexpected error during parsing: fail open.
        return
      }

      if (shouldBlock) {
        throw new Error(reason)
      }
    },

    /**
     * tool.execute.after: STATE-CONTINUITY ADVISORIES
     *
     * Runs three advisory checks, never blocks:
     * 1. Cross-mission staleness (active mission has at least one own row).
     * 2. Within-mission lag (last done PROGRESS step vs newest FLIGHT-RECORDER step),
     *    skipped for writes under .opencode/memory/.
     * 3. Structural validation of the newest FLIGHT-RECORDER row.
     */
    "tool.execute.after": async (_input: any, output: any) => {
      try {
        const args = output?.args || {}
        const filePath =
          args?.filePath ||
          args?.path ||
          args?.file ||
          args?.file_path ||
          ""

        // G1: skip the lag check for state-machine writes.
        const runLagCheck =
          typeof filePath === "string" &&
          filePath.length > 0 &&
          !filePath.includes(".opencode/memory/")

        const projectRoot = resolveProjectRoot(ctx, filePath || undefined)
        const currentMissionPath = `${projectRoot}/.opencode/memory/state/CURRENT-MISSION.md`
        const flightRecorderPath = `${projectRoot}/.opencode/memory/state/FLIGHT-RECORDER.md`

        const currentContent = readUtf8File(currentMissionPath)
        if (!currentContent) {
          return
        }

        const currentMissionID = parseMissionID(currentContent)
        if (!currentMissionID) {
          return
        }

        // A completed mission is not an active mission. The pointer file
        // deliberately still names the last mission after close (see
        // .opencode/templates/state/STATE-FILE-TEMPLATE.md), so continuity
        // advisories — and the central-mode mirror below — step aside until a
        // new mission replaces the pointer. "not-started" is NOT silenced: the
        // staleness check already tolerates brand-new missions (it only warns
        // once the mission has a row of its own), and silencing it would also
        // skip the mirror for stand-up rows.
        const currentMissionStatus = parseMissionStatus(currentContent)
        if (currentMissionStatus === "complete") {
          return
        }

        const flightContent = readUtf8File(flightRecorderPath)
        if (flightContent === undefined) {
          console.warn(
            `[mission-guard] State-continuity warning: FLIGHT-RECORDER.md is missing for active mission ${currentMissionID}.`
          )
          return
        }

        // A freshly seeded journal has no data rows, and stand-up points
        // CURRENT-MISSION.md at the new mission before its mission-start row is
        // appended. That is the same brand-new-mission window the cross-mission
        // check below tolerates, so stay silent rather than warn on every tool
        // call of a first mission's stand-up.
        const dataRows = getFlightRecorderDataRows(flightContent)
        if (dataRows.length === 0) {
          return
        }

        const lastRow = dataRows[dataRows.length - 1]
        const secondLastRow =
          dataRows.length > 1 ? dataRows[dataRows.length - 2] : null
        const lastMissionID = parseRowMissionID(lastRow)
        if (!lastMissionID) {
          console.warn(
            `[mission-guard] State-continuity warning: Could not parse Mission ID from FLIGHT-RECORDER.md last row.`
          )
          return
        }

        // Cross-mission staleness: only warn once the active mission has logged
        // at least one row of its own. A brand-new mission may legitimately still
        // have the previous mission's row as the newest entry.
        const currentMissionHasRow = dataRows.some(
          (row) => parseRowMissionID(row) === currentMissionID
        )
        if (lastMissionID !== currentMissionID && currentMissionHasRow) {
          console.warn(
            `[mission-guard] State-continuity warning: FLIGHT-RECORDER.md may not have advanced for ${currentMissionID} (newest row is for ${lastMissionID}).`
          )
        }

        // Within-mission lag: compare PROGRESS.md last done step with the newest
        // journal step, but only for ordinary (non-memory) writes.
        if (runLagCheck && lastMissionID === currentMissionID) {
          const progressPath = `${projectRoot}/.opencode/memory/missions/${currentMissionID}/PROGRESS.md`
          if (existsSync(progressPath)) {
            const progressContent = readUtf8File(progressPath)
            if (progressContent) {
              const lastDoneStep = findLastDoneStep(progressContent)
              if (lastDoneStep) {
                const journalStep = parseRowStep(lastRow)
                if (journalStep && journalStep !== "—" && journalStep !== lastDoneStep) {
                  console.warn(
                    `[mission-guard] State-continuity warning: PROGRESS.md last done step is ${lastDoneStep} but FLIGHT-RECORDER.md newest row has step ${journalStep}.`
                  )
                }
              }
            }
          }
        }

        // Structural validation of the newest row.
        const validationErrors = validateFlightRecorderRow(
          lastRow,
          secondLastRow
        )
        if (validationErrors.length > 0) {
          console.warn(
            `[mission-guard] State-continuity warning: FLIGHT-RECORDER.md newest row has issues: ${validationErrors.join(
              "; "
            )}`
          )
        }

        // ----------------------------------------------------------------------
        // Central-mode mirror (advisory only).
        //
        // Targets POST /v1/events, provisional per operator decision Q8 in
        // task-20260916-01 CONTEXT.md. The original source harness hook posted
        // to /v1/flight-recorder, but that endpoint was never registered by
        // memoryd; the real service exposes POST /v1/events.
        //
        // Triggered only for writes under .opencode/memory/ (the same memory-tree
        // writes that update FLIGHT-RECORDER.md). Fire-and-forget, ~2s timeout,
        // never throws, never writes local state.
        //
        // Mirrors only rows that passed structural validation: the source hook
        // skips invalid rows, and the service would reject them anyway.
        // ----------------------------------------------------------------------
        if (
          typeof filePath === "string" &&
          filePath.includes(".opencode/memory/") &&
          validationErrors.length === 0
        ) {
          const conf = parseBishopMemoryConf(projectRoot)
          if (isCentralModeEnabled(conf)) {
            const checksum = rowChecksum(lastRow)
            if (checksum !== lastMirroredChecksum) {
              // The checksum is recorded before fetch resolves. This is
              // intentional: the mirror is advisory, must never block, and must
              // never write local pending state. It therefore differs from the
              // source hook's file-based cursor (updated only after a successful
              // POST), which retries failed mirrors on the next write.
              lastMirroredChecksum = checksum
              mirrorFlightRecorderRow(lastRow, conf)
            }
          }
        }
      } catch {
        // Advisory hook must never throw or block.
        return
      }
    },
  }
}
