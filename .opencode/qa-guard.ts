import { appendFileSync, mkdirSync, readFileSync } from "fs"
import { resolve } from "path"

/**
 * qa-guard.ts
 *
 * Opencode plugin port of the Ripley QA guard from the Claude harness.
 *
 * Runs before every tool call. On Playwright browser tools it enforces:
 *   - origin allowlist default-deny
 *   - save_to_disk refusal
 *   - recognised path-field confinement to `.opencode/memory/workspace/qa/`
 *     (`sourcePath` may also read from `.opencode/skills/visual-qa/`)
 *
 * When the running agent is identifiable as `ripley`, Write/Edit path fields
 * are also confined to the QA workspace.
 *
 * Dropped semantics from the source hook:
 *   - workspace-trust gating (no opencode equivalent)
 *   - the "never in -p" rule (no opencode equivalent)
 *
 * Exports EXACTLY ONE factory (`qaGuard`). Extra exports silently break the
 * opencode plugin loader.
 */

interface PluginInput {
  directory?: string
  worktree?: string
  [key: string]: unknown
}

type Plugin = (
  ctx: PluginInput
) => Promise<{ [hookName: string]: (...args: any[]) => any }>

interface ParsedOrigin {
  scheme: string
  host: string
  port: number | "*"
  wild: boolean
}

interface OriginListResult {
  errors: string[]
  parsed: ParsedOrigin[]
}

interface QaConf {
  allowed: string
  allowedSet: boolean
  blocked: string
}

const DEFAULT_ALLOWED_ORIGINS =
  "http://localhost:* https://localhost:* http://127.0.0.1:* https://127.0.0.1:* http://[::1]:* https://[::1]:*"

const RECOGNISED_PATH_REGEX =
  /(path|paths|file|files|filename|filenames|dir|directory)$/i

// ---------------------------------------------------------------------------
// Defensive file I/O
// ---------------------------------------------------------------------------

/**
 * Read a UTF-8 file defensively.
 *
 * Opencode's runtime fs shim can return `undefined` for missing or sandboxed
 * files. This helper normalizes those cases to `undefined`.
 *
 * @param filePath - Absolute path to the file.
 * @returns The file contents, or `undefined` if unreadable.
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
 * Resolve the project root from plugin context.
 *
 * @param ctx - Plugin context.
 * @returns Project root path.
 */
function resolveProjectRoot(ctx: PluginInput): string {
  if (ctx?.directory) return ctx.directory.replace(/\/$/, "")
  if (ctx?.worktree) return ctx.worktree.replace(/\/$/, "")
  return process.cwd()
}

// ---------------------------------------------------------------------------
// Tool-shape extraction
// ---------------------------------------------------------------------------

/**
 * Extract the tool name from the hook input object.
 *
 * Tries every observed or plausible field name.
 *
 * @param input - Hook input.
 * @returns Tool name, or "unknown".
 */
function extractToolName(input: any): string {
  if (!input || typeof input !== "object") return "unknown"
  const candidates = [
    input.tool,
    input.toolName,
    input.tool_name,
    input.name,
    input.toolId,
    input.tool_id,
  ]
  for (const c of candidates) {
    if (typeof c === "string" && c.length > 0) return c
  }
  return "unknown"
}

/**
 * Extract tool arguments from the hook input/output pair.
 *
 * The opencode contract places them on `output.args`, but we check equivalents.
 *
 * @param input - Hook input.
 * @param output - Hook output / tool-call descriptor.
 * @returns Arguments object, defaulting to `{}`.
 */
function extractArgs(input: any, output: any): any {
  const args =
    output?.args ?? input?.args ?? output?.arguments ?? input?.arguments ?? {}
  return args && typeof args === "object" ? args : {}
}

/**
 * Return the first string value of a top-level key matching /agent/i.
 *
 * Used for probe logging and for the Ripley-scoped full guard.
 *
 * @param input - Hook input.
 * @returns Agent identity, or `undefined`.
 */
function extractAgentIdentity(input: any): string | undefined {
  if (!input || typeof input !== "object") return undefined
  for (const key of Object.keys(input)) {
    if (/agent/i.test(key)) {
      const value = input[key]
      if (typeof value === "string") return value
    }
  }
  return undefined
}

// ---------------------------------------------------------------------------
// Browser-tool detection
// ---------------------------------------------------------------------------

/**
 * Determine whether a tool name identifies a Playwright browser tool.
 *
 * @param toolName - Tool name.
 * @returns True if this is a browser tool.
 */
function isPlaywrightBrowserTool(toolName: string): boolean {
  const lower = toolName.toLowerCase()
  return lower.includes("playwright") || lower.startsWith("mcp__playwright__")
}

/**
 * Determine whether a tool name is Write or Edit.
 *
 * @param toolName - Tool name.
 * @returns True for `Write` and `Edit`.
 */
function isWriteOrEditTool(toolName: string): boolean {
  return toolName === "Write" || toolName === "Edit"
}

// ---------------------------------------------------------------------------
// Configuration parsing
// ---------------------------------------------------------------------------

/**
 * Parse `.opencode/qa.conf`.
 *
 * Grammar (matches the source POSIX sh parser):
 *   - Skip blank lines and lines starting with `#`.
 *   - Split on the FIRST `=` only.
 *   - No trimming, no quote stripping.
 *   - Last occurrence of a repeated key wins.
 *
 * Only `QA_ALLOWED_ORIGINS` and `QA_BLOCKED_ORIGINS` are read. A missing or
 * unreadable conf returns empty defaults; the caller substitutes the localhost
 * allowlist when `allowedSet` is false.
 *
 * @param projectRoot - Project root.
 * @returns Parsed QA configuration.
 */
function parseQaConf(projectRoot: string): QaConf {
  const result: QaConf = { allowed: "", allowedSet: false, blocked: "" }
  const content = readUtf8File(`${projectRoot}/.opencode/qa.conf`)
  if (!content) return result

  for (const line of content.split("\n")) {
    if (line === "" || line.startsWith("#")) continue
    const eq = line.indexOf("=")
    if (eq === -1) continue
    const key = line.slice(0, eq)
    const value = line.slice(eq + 1)
    if (key === "QA_ALLOWED_ORIGINS") {
      result.allowed = value
      result.allowedSet = true
    } else if (key === "QA_BLOCKED_ORIGINS") {
      result.blocked = value
    }
  }
  return result
}

// ---------------------------------------------------------------------------
// URL and origin parsing
// ---------------------------------------------------------------------------

/**
 * Test whether a Unicode code point is a "bad character" for URLs.
 *
 * Mirrors the source jq definition.
 *
 * @param code - Code point.
 * @returns True if disallowed.
 */
function isBadUrlChar(code: number): boolean {
  if (code <= 32 || code === 92) return true
  if (code >= 127 && code <= 160) return true
  if (
    code === 5760 ||
    (code >= 8192 && code <= 8202) ||
    code === 8232 ||
    code === 8233 ||
    code === 8239 ||
    code === 8287 ||
    code === 12288
  ) {
    return true
  }
  return false
}

/**
 * Test whether a string contains a control character.
 *
 * @param s - String to test.
 * @returns True if a control character is present.
 */
function hasControlChar(s: string): boolean {
  for (let i = 0; i < s.length; i++) {
    const code = s.charCodeAt(i)
    if (code < 32 || code === 127) return true
  }
  return false
}

/**
 * Validate a URL host string.
 *
 * @param host - Lower-cased host.
 * @returns True if valid.
 */
function isValidHost(host: string): boolean {
  if (host.startsWith("[")) return /^\[[0-9a-f:.]+\]$/.test(host)
  return /^[a-z0-9-]+(\.[a-z0-9-]+)*$/.test(host)
}

/**
 * Validate and parse a port string.
 *
 * Rejects leading zeros and values outside 1-65535.
 *
 * @param port - Port string.
 * @returns Parsed port, or `null` if invalid.
 */
function parsePort(port: string): number | null {
  if (!/^[1-9][0-9]{0,4}$/.test(port)) return null
  const n = Number(port)
  return n <= 65535 ? n : null
}

/**
 * Drop a single trailing dot from a host unless it is an IPv6 literal.
 *
 * @param host - Host string.
 * @returns Host with trailing dot removed.
 */
function dropTrailingDot(host: string): string {
  if (host.startsWith("[")) return host
  if (host.endsWith(".")) return host.slice(0, -1)
  return host
}

/**
 * Parse a URL argument from a browser tool call.
 *
 * Accepts `about:blank`. Rejects relative URLs, userinfo, and malformed hosts.
 *
 * @param url - URL argument.
 * @returns Parsed URL, blank sentinel, or error message.
 */
function parseUrl(
  url: string
): { scheme: string; host: string; port: number } | { blank: true } | { err: string } {
  if (typeof url !== "string" || url.length === 0) {
    return { err: "url must be a non-empty string" }
  }
  if (url === "about:blank") return { blank: true }

  for (let i = 0; i < url.length; i++) {
    if (isBadUrlChar(url.charCodeAt(i))) {
      return { err: "url contains a backslash, whitespace or control character" }
    }
  }

  const match = url.match(/^(?<scheme>https?):\/\/(?<rest>.*)$/i)
  if (!match || !match.groups) {
    return { err: "url must be about:blank or an absolute http(s) URL" }
  }

  const scheme = match.groups.scheme.toLowerCase()
  const rest = match.groups.rest
  const authEnd = rest.search(/[/?#]/)
  const auth = authEnd === -1 ? rest : rest.slice(0, authEnd)

  if (auth.length === 0) return { err: "url has an empty host" }
  if (auth.includes("@")) return { err: "url carries userinfo (user@host)" }

  const hpMatch = auth.match(/^(?<h>\[[^\]]*\]|[^:\[\]]*)(?::(?<p>.*))?$/)
  if (!hpMatch || !hpMatch.groups) return { err: "url authority is malformed" }

  const host = dropTrailingDot(hpMatch.groups.h.toLowerCase())
  if (!isValidHost(host)) {
    return { err: "url host is not a valid hostname or IPv6 literal" }
  }

  const portStr = hpMatch.groups.p
  let port: number
  if (portStr === undefined || portStr === null || portStr === "") {
    port = scheme === "http" ? 80 : 443
  } else {
    const parsed = parsePort(portStr)
    if (parsed === null) {
      return { err: "url port is not 1-65535 or has a leading zero" }
    }
    port = parsed
  }

  return { scheme, host, port }
}

/**
 * Parse a single origin allowlist/blocklist entry.
 *
 * Entries are shaped `scheme://host[:port or :*]`. A leading `*.` matches any
 * depth of subdomains. Missing port matches the scheme's default only. `:*`
 * matches any port.
 *
 * @param entry - Raw origin entry.
 * @returns Parsed origin, or `null` if malformed.
 */
function parseOriginEntry(entry: string): ParsedOrigin | null {
  if (typeof entry !== "string" || entry.length === 0) return null
  if (hasControlChar(entry)) return null
  for (let i = 0; i < entry.length; i++) {
    if (isBadUrlChar(entry.charCodeAt(i))) return null
  }

  const match = entry.match(
    /^(?<scheme>https?):\/\/(?<h>\[[^\]]*\]|[^:/?#@\[\]]+)(?::(?<p>.*))?$/i
  )
  if (!match || !match.groups) return null

  const rawHost = match.groups.h.toLowerCase()
  const wild = rawHost.startsWith("*.")
  const host = dropTrailingDot(wild ? rawHost.slice(2) : rawHost)
  const scheme = match.groups.scheme.toLowerCase()

  if (!isValidHost(host) || (wild && host.startsWith("["))) return null

  const portStr = match.groups.p
  let port: number | "*"
  if (portStr === undefined || portStr === null || portStr === "") {
    port = scheme === "http" ? 80 : 443
  } else if (portStr === "*") {
    port = "*"
  } else {
    const parsed = parsePort(portStr)
    if (parsed === null) return null
    port = parsed
  }

  return { scheme, host, port, wild }
}

/**
 * Split an origin list value into entries and parse each one.
 *
 * The source splits on spaces and ignores empty fragments.
 *
 * @param key - Configuration key name.
 * @param value - Raw list value.
 * @returns Parsed list result.
 */
function checkOriginList(key: string, value: string): OriginListResult {
  const result: OriginListResult = { errors: [], parsed: [] }

  if (hasControlChar(value)) {
    result.errors.push(
      `${key} contains a control character such as a carriage return; check .opencode/qa.conf for CRLF line endings and fix it`
    )
    return result
  }

  const rawEntries = value.split(" ").filter((s) => s.length > 0)
  for (const raw of rawEntries) {
    const parsed = parseOriginEntry(raw)
    if (parsed === null) {
      result.errors.push(
        `${key} has a malformed entry: ${raw} (expected http(s)://host[:port or :*], no path); fix .opencode/qa.conf`
      )
    } else {
      result.parsed.push(parsed)
    }
  }

  return result
}

/**
 * Test whether an origin matches a parsed allowlist/blocklist entry.
 *
 * @param entry - Parsed origin entry.
 * @param scheme - Origin scheme.
 * @param host - Origin host.
 * @param port - Origin port.
 * @returns True if the entry covers the origin.
 */
function originMatch(
  entry: ParsedOrigin,
  scheme: string,
  host: string,
  port: number
): boolean {
  if (entry.scheme !== scheme) return false
  if (entry.port !== "*" && entry.port !== port) return false
  if (entry.wild) return host.endsWith("." + entry.host)
  return host === entry.host
}

// ---------------------------------------------------------------------------
// Path confinement
// ---------------------------------------------------------------------------

/**
 * Test whether a top-level argument key is a recognised path field.
 *
 * @param key - Argument key.
 * @returns True if the key is a recognised path field.
 */
function isRecognisedPathField(key: string): boolean {
  return RECOGNISED_PATH_REGEX.test(key)
}

/**
 * Split a path into normalised segments, dropping empty and `.` segments.
 *
 * @param p - Raw path.
 * @returns Array of path segments.
 */
function getSegments(p: string): string[] {
  return p.split("/").filter((s) => s !== "" && s !== ".")
}

/**
 * Test whether a single path value is confined to the QA workspace.
 *
 * `sourcePath` is additionally allowed under `.opencode/skills/visual-qa/`.
 *
 * @param key - Argument key (for the sourcePath exception).
 * @param rawPath - Path string.
 * @param rootSegments - Project root split into segments.
 * @returns True if the path is confined.
 */
function pathOk(
  key: string,
  rawPath: string,
  rootSegments: string[]
): boolean {
  if (rawPath.length === 0 || rawPath.startsWith("~")) return false

  const segments = getSegments(rawPath)
  if (segments.some((s) => s === "..")) return false

  const absoluteSegments = rawPath.startsWith("/")
    ? segments
    : rootSegments.concat(segments)

  const qaSegments = rootSegments.concat(
    ".opencode",
    "memory",
    "workspace",
    "qa"
  )
  const vqSegments = rootSegments.concat(
    ".opencode",
    "skills",
    "visual-qa"
  )

  const underQa =
    absoluteSegments.length >= qaSegments.length &&
    qaSegments.every((seg, i) => absoluteSegments[i] === seg)

  if (underQa) return true

  if (key === "sourcePath") {
    const underVq =
      absoluteSegments.length >= vqSegments.length &&
      vqSegments.every((seg, i) => absoluteSegments[i] === seg)
    return underVq
  }

  return false
}

/**
 * Validate a path argument value.
 *
 * @param key - Argument key.
 * @param value - Argument value.
 * @param rootSegments - Project root segments.
 * @returns Array of error messages (empty if valid).
 */
function pathCheck(
  key: string,
  value: unknown,
  rootSegments: string[]
): string[] {
  if (typeof value === "string") {
    if (pathOk(key, value, rootSegments)) return []
    const preview = JSON.stringify(value.length > 120 ? value.slice(0, 120) : value)
    return [
      `File path refused: ${key} = ${preview} is not inside .opencode/memory/workspace/qa/ (or is relative-escaping, empty or ~)`,
    ]
  }

  if (Array.isArray(value)) {
    const ok = value.every(
      (item) => typeof item === "string" && pathOk(key, item, rootSegments)
    )
    if (ok) return []
    return [
      `File path refused: ${key} holds an element that is not a string path inside .opencode/memory/workspace/qa/`,
    ]
  }

  return [`File path refused: ${key} must be a string or an array of strings`]
}

// ---------------------------------------------------------------------------
// Probe logging and predicates
// ---------------------------------------------------------------------------

/**
 * Append a single probe line for every tool call.
 *
 * Records the timestamp, tool name, top-level input keys, and any
 * agent-identifying field values. Never logs full arguments, URLs, or content.
 *
 * @param projectRoot - Project root.
 * @param input - Hook input.
 * @param toolName - Extracted tool name.
 * @param identity - Extracted agent identity, if any.
 */
function appendProbeLog(
  projectRoot: string,
  input: any,
  toolName: string,
  identity: string | undefined
): void {
  try {
    const dir = resolve(projectRoot, ".opencode/memory/workspace/qa")
    mkdirSync(dir, { recursive: true })

    const inputKeys =
      input && typeof input === "object" ? Object.keys(input) : []

    const agentFields: Array<{ key: string; value: string }> = []
    if (input && typeof input === "object") {
      for (const key of Object.keys(input)) {
        if (/agent/i.test(key)) {
          const value = input[key]
          if (typeof value === "string") agentFields.push({ key, value })
        }
      }
    }

    const line = JSON.stringify({
      timestamp: new Date().toISOString(),
      tool: toolName,
      scope: identity === "ripley" ? "ripley" : "fallback",
      inputKeys,
      agentFields,
    })

    appendFileSync(resolve(dir, "guard-probe.log"), line + "\n")
  } catch {
    // Probe logging is observability only; failures must never break the loop.
  }
}

/**
 * Determine whether a `save_to_disk` argument value is truthy.
 *
 * Matches boolean `true` or the string `"true"` (case-insensitive).
 *
 * @param value - The argument value.
 * @returns True if the call must be refused.
 */
function isTruthySaveToDisk(value: unknown): boolean {
  if (value === true) return true
  if (typeof value === "string" && value.toLowerCase() === "true") return true
  return false
}

// ---------------------------------------------------------------------------
// Plugin factory
// ---------------------------------------------------------------------------

/**
 * QA guard plugin factory.
 *
 * @param ctx - Plugin context provided by opencode.
 * @returns Object with the before-execution hook.
 */
export const qaGuard: Plugin = async (ctx: PluginInput) => {
  return {
    /**
     * tool.execute.before: QA guard.
     *
     * Always logs a probe line. For Playwright browser tools, enforces origin
     * allowlist/blocklist, refuses save_to_disk, and confines recognised path
     * fields. When the running agent is `ripley`, Write/Edit path fields are
     * also confined.
     */
    "tool.execute.before": async (input: any, output: any) => {
      const toolName = extractToolName(input)
      const args = extractArgs(input, output)
      const identity = extractAgentIdentity(input)
      const projectRoot = resolveProjectRoot(ctx)

      appendProbeLog(projectRoot, input, toolName, identity)

      const isBrowser = isPlaywrightBrowserTool(toolName)
      const isWriteEdit = isWriteOrEditTool(toolName)

      // Safe fallback: only browser tools are guarded unless we can see Ripley.
      if (!isBrowser && !(identity === "ripley" && isWriteEdit)) {
        return
      }

      const rootSegments = getSegments(projectRoot)

      if (isBrowser) {
        // Conf is read lazily, only when a browser tool is actually used.
        const conf = parseQaConf(projectRoot)
        const allowedStr = conf.allowedSet
          ? conf.allowed
          : DEFAULT_ALLOWED_ORIGINS
        const blockedStr = conf.blocked

        const allowList = checkOriginList("QA_ALLOWED_ORIGINS", allowedStr)
        const blockList = checkOriginList("QA_BLOCKED_ORIGINS", blockedStr)
        const errors: string[] = [...allowList.errors, ...blockList.errors]

        if (typeof args.url === "string") {
          const parsed = parseUrl(args.url)
          if ("err" in parsed) {
            errors.push(`Navigation refused: ${parsed.err}`)
          } else if (!("blank" in parsed)) {
            const origin = `${parsed.scheme}://${parsed.host}:${parsed.port}`
            const blocked = blockList.parsed.some((entry) =>
              originMatch(entry, parsed.scheme, parsed.host, parsed.port)
            )
            if (blocked) {
              errors.push(
                `Navigation refused: ${origin} is blocked by QA_BLOCKED_ORIGINS`
              )
            } else {
              const allowed = allowList.parsed.some((entry) =>
                originMatch(entry, parsed.scheme, parsed.host, parsed.port)
              )
              if (!allowed) {
                errors.push(
                  `Navigation refused: ${origin} is not in QA_ALLOWED_ORIGINS; list it in .opencode/qa.conf if it is meant to be allowed`
                )
              }
            }
          }
        }

        if (isTruthySaveToDisk(args.save_to_disk)) {
          errors.push(
            "save_to_disk is true; the destination of that file cannot be checked"
          )
        }

        if (args && typeof args === "object") {
          for (const [key, value] of Object.entries(args)) {
            if (isRecognisedPathField(key)) {
              errors.push(...pathCheck(key, value, rootSegments))
            }
          }
        }

        if (errors.length > 0) {
          throw new Error(`qa-guard: ${errors[0]}`)
        }
        return
      }

      // Ripley Write/Edit path confinement.
      if (identity === "ripley" && isWriteEdit) {
        if (args && typeof args === "object") {
          for (const [key, value] of Object.entries(args)) {
            if (isRecognisedPathField(key)) {
              const errs = pathCheck(key, value, rootSegments)
              if (errs.length > 0) {
                throw new Error(`qa-guard: ${errs[0]}`)
              }
            }
          }
        }
      }
    },
  }
}
