# Installing the Bishop Harness

The harness is delivered in three layers. This matches how opencode loads configuration: a portable layer shipped with the harness, a per-project runtime layer, and a private runtime layer that is never committed.

## The three layers

1. **Portable layer** — files that move with the harness installer:
   - Root: `AGENTS.md`, `SOUL.md`, `CREW-MANIFEST.md`, `opencode.json`
   - `.opencode/`: agents, commands, skills, templates, plugins, `memory.zip`, `.gitignore`
2. **Per-project layer** — `opencode.json` in the target project root. The installer copies or merges the portable `opencode.json` so the target project knows about the Bishop crew. If the target already has an `opencode.json`, the installer backs it up and warns unless `--force` is used.
3. **Runtime layer** — files that are created while the harness runs and are always ignored by git:
   - `.opencode/memory/`
   - `.opencode/about/`
   - `.opencode/bishop-memory.conf`

## Quick install

From the harness checkout:

```bash
./install-harness.sh /path/to/target-project
```

What the script does:

1. Validates the target path.
2. Copies the portable layer into the target:
   - `AGENTS.md`, `SOUL.md`, `CREW-MANIFEST.md`, `opencode.json`
   - `.opencode/` (agents, commands, skills, templates, plugins, `memory.zip`, `.gitignore`)
3. Seeds `.opencode/memory/` from `.opencode/memory.zip` when present. The zip contains a top-level `memory/` folder; the installer extracts it to a temp directory, strips that folder, and places the contents so the result is:
   ```text
   .opencode/memory/state/{CURRENT-MISSION,FLIGHT-RECORDER,MISSION-ARCHIVE}.md
   .opencode/memory/missions/
   .opencode/memory/workspace/
   .opencode/memory/findings/
   .opencode/memory/reference/DIRECTIVES.md
   ```
   - Memory counts as seeded only when `.opencode/memory/state/CURRENT-MISSION.md` exists. A bare or wrongly nested `.opencode/memory/` is topped up with the missing seed files; existing files are never overwritten.
   - If an earlier install left `.opencode/memory/memory/`, the installer moves its contents up one level (`mv -n`, no clobber), reports every move, and removes the empty nested folder. It refuses, before copying anything, when both the nested and the top-level copies hold state files.
   - `--force` re-seeds: it backs up `.opencode/memory/` and then overwrites existing files with the seed, state files included.
4. Appends the harness paths to `.git/info/exclude` so runtime files stay out of the product repo. When the target is not a git repository, this step is skipped with a one-line notice.
5. Reports what was copied and what to do next.

## Flags

- `--dry-run` — show what would be copied, but change nothing. Memory seeding and repair report each exact destination path they would create or move.
- `--force` — overwrite existing harness files and re-seed memory even if they already exist. Re-seeding replaces existing state files after backing up `.opencode/memory/`.
- `--update` — refresh an existing install with the current harness files. See [Updating an existing install](#updating-an-existing-install). Cannot be combined with `--force`.
- `--help` — show usage.

## Updating an existing install

To bring a project that already runs the harness up to date, without touching its memory or local config:

```bash
./install-harness.sh --update --dry-run /path/to/target-project   # report only
./install-harness.sh --update /path/to/target-project
```

What it covers:

- `AGENTS.md`, `SOUL.md`, `CREW-MANIFEST.md`, and every harness file under `.opencode/` (agents, commands, skills, templates, lib, plugins, `memory.zip`, examples).
- It never reads or writes `.opencode/memory/`, `.opencode/about/`, `bishop-memory.conf`, `qa.conf`, `node_modules/`, or `package*.json`.

How it decides:

- A file missing from the target is added (`NEW`).
- A file is replaced (`CHANGED`) when its size differs. When the sizes match, the bytes are compared too, so an edit that keeps the length is still caught.
- Each replaced file is first copied to `.bishop-backups/update-<timestamp>/`, keeping its relative path. In git targets that folder is added to `.git/info/exclude`.
- `opencode.json` is never written, because it holds the target's own provider and MCP config. Instead the harness-owned keys (`agent`, `plugin`, `instructions`, `tools`, `default_agent`) are compared, and any difference is listed under `REVIEW` for you to merge by hand.
- Files that exist only in the target, such as a skill removed from the harness, are listed under `EXTRA` and left in place.

The run ends with a short colour-coded summary (`NEW`, `CHANGED`, `SAME`, `REVIEW`, `EXTRA`). Set `NO_COLOR=1` to turn the colour off. With `--dry-run` nothing is written, and the summary says where the backups would go.

## Manual install

If you prefer not to run the script:

1. Copy the portable root files into the target project:
   - `AGENTS.md`
   - `SOUL.md`
   - `CREW-MANIFEST.md`
   - `opencode.json`
2. Copy the portable `.opencode/` tree into the target project.
3. Extract `.opencode/memory.zip` into `.opencode/` (not `.opencode/memory/`) — the zip already contains a top-level `memory/` folder. Confirm `.opencode/memory/state/CURRENT-MISSION.md` exists.
4. Add the following to `.git/info/exclude` in the target project:
   ```text
   /.opencode/
   /AGENTS.md
   /SOUL.md
   /CREW-MANIFEST.md
   /opencode.json
   ```
5. Open the target project in opencode.

## After installing

Work through these in order. Steps 2 and 3 are optional; the rest are not.

1. **Configure the user-level providers** `opencode-go` and `opencode-go-minimax` before first launch. See [Provider configuration](#provider-configuration).
2. **Optional — central memory.**
   1. Confirm the bishop-memory daemon is healthy: `http://127.0.0.1:8787/healthz` responds.
   2. Copy `.opencode/bishop-memory.conf.example` to `.opencode/bishop-memory.conf` and set `BISHOP_MEMORY_MODE=central`, a unique `BISHOP_HARNESS`, and `BISHOP_MEMORY_HOME`.
   3. Run `.opencode/connect-bishop-memory.sh --dry-run`, then run it for real. The first real run writes `opencode.json.bak`; it is safe to re-run.
3. **Optional — QA.** Add the Playwright `mcp` entry next to `bishop-memory` in the same `mcp` block of `opencode.json` (see [Browser Setup For Ripley](#browser-setup-for-ripley)). `.opencode/qa.conf` is needed only for non-localhost targets — no conf means localhost only. A link checker is optional (for example `brew install lychee`).
4. **Restart opencode once**, after all config changes, and approve each project-scope MCP server when prompted (`bishop-memory`, `playwright`).
5. **Verify.**
   - `bishop` is the default agent.
   - All six agents load: `bishop`, `hicks`, `apone`, `vasquez`, `lambert`, `ripley`.
   - In central mode, a new mission ID comes from `mission_allocate`.

Then start a mission by describing the objective to `bishop`.

## Browser Setup For Ripley

Ripley drives a browser to verify rendered work against intent — visual fidelity, functional flow, responsive behaviour, technical integrity, accessibility. Her procedure is the `visual-qa` skill under `.opencode/skills/visual-qa/`; her browser tools come from the Playwright MCP server, which you register in `opencode.json`'s `mcp` block. She invokes them by whatever names your tool list shows; she never uses the server's arbitrary code-execution or browser-install tools — those are disabled globally via the `tools` map in `opencode.json`. File writes are confined by the qa-guard plugin.

**Playwright MCP registration.** Add the following `mcp` entry to `opencode.json`:

```json
"mcp": {
  "playwright": {
    "type": "local",
    "command": ["npx", "-y", "@playwright/mcp"],
    "enabled": true,
    "timeout": 30000
  }
}
```

**Second layer — origin limits.** The guard sees only direct navigation, so set the browser server's own origin limits as well. Copy `.opencode/qa.conf.example` to `.opencode/qa.conf` and set `QA_ALLOWED_ORIGINS` and `QA_BLOCKED_ORIGINS`. Without a conf, or one that doesn't set `QA_ALLOWED_ORIGINS`, only localhost (`localhost`, `127.0.0.1`, `[::1]`, any port) is allowed. A set `QA_ALLOWED_ORIGINS` replaces that default, and `QA_BLOCKED_ORIGINS` always wins — production belongs there. The operator writes it; the crew does not.

**After changing config**, quit and restart opencode. Approve the Playwright MCP server at project scope when prompted. New MCP servers and changes to agent files take effect only after a restart.

**Requirements.** No `jq` dependency — unlike the Claude harness, the guard is a TypeScript plugin (`.opencode/qa-guard.ts`) loaded directly by opencode, so it needs no external JSON tool on PATH.

**Global tool disables.** The `tools` map in `opencode.json` disables the browser arbitrary-code-execution and install tools globally, in both naming forms:

```json
"tools": {
  "mcp__playwright__browser_run_code_unsafe": false,
  "mcp__playwright__browser_install": false,
  "playwright_browser_run_code_unsafe": false,
  "playwright_browser_install": false
}
```

**The qa-guard plugin.** The fail-closed backstop (`.opencode/qa-guard.ts`) refuses any write whose recognised path field falls outside `.opencode/memory/workspace/qa/` and any URL outside the allowlist. It logs every tool call to `.opencode/memory/workspace/qa/guard-probe.log`.

**Optional link checker.** If one is installed (for example `lychee`, `linkinator` or `muffet`), Bishop runs it read-only before Ripley's first pass. The harness never installs one.

**Optional design source.** To give Ripley a design server (Figma's MCP server, for example), register it in the `mcp` block of `opencode.json` and disable its write tools via the global `tools` map.

## Plugin type check

`mission-guard.ts` is a TypeScript opencode plugin. To type-check it without committing `node_modules` or `package.json` to the harness:

```bash
npm install --prefix /tmp/bishop-ts typescript @types/node
/tmp/bishop-ts/node_modules/.bin/tsc \
  --noEmit --module Node16 --moduleResolution Node16 \
  --target ES2022 --esModuleInterop --skipLibCheck --strict false \
  --types node --typeRoots /tmp/bishop-ts/node_modules/@types \
  --lib es2022 \
  .opencode/mission-guard.ts
```

Run this before packaging or after any change to the plugin. It is a one-shot validation step, not a build dependency — the plugin is loaded directly by opencode as TypeScript; it is not compiled into the repo.

## Provider configuration

The harness's `opencode.json` does **not** ship a project-level `providers` block. Instead, model routing depends on two user-level opencode providers:

- `opencode-go` — the default provider for `opencode-go/glm-5.2`, `opencode-go/kimi-k2.7-code`, `opencode-go/kimi-k2.6`, and `opencode-go/hy3`.
- `opencode-go-minimax` — the same API key as `opencode-go`, but registered as a separate provider so opencode routes MiniMax/Qwen models (`opencode-go-minimax/qwen3.7-plus`) through it.

On a fresh machine, configure both providers in your user-level opencode config **before** opening a project with this harness, otherwise the models listed in `opencode.json` will not resolve. The harness intentionally keeps provider credentials out of the project; they belong in user config.

## Central memory setup (optional)

1. Install the `bishop-memory` service and confirm `http://127.0.0.1:8787/healthz` responds.
2. Copy `.opencode/bishop-memory.conf.example` to `.opencode/bishop-memory.conf` and set `BISHOP_MEMORY_MODE=central`, a unique `BISHOP_HARNESS` name, and `BISHOP_MEMORY_HOME`.
3. Run `.opencode/connect-bishop-memory.sh` to write the `mcp` block into `opencode.json`.
4. Restart opencode and approve the project-scope MCP server.

## Checklist

After install, the target project should have:

- [ ] `AGENTS.md`
- [ ] `SOUL.md`
- [ ] `CREW-MANIFEST.md`
- [ ] `opencode.json`
- [ ] `.opencode/agents/{bishop,hicks,apone,vasquez,lambert}.md`
- [ ] `.opencode/memory/` seeded
- [ ] `.opencode/memory/state/CURRENT-MISSION.md` exists (not nested under `.opencode/memory/memory/`)
- [ ] `.opencode/agents/ripley.md`
- [ ] Playwright MCP registered in `opencode.json` `mcp` block
- [ ] `.opencode/qa-guard.ts` listed in `opencode.json` `plugin` array
- [ ] `.opencode/qa.conf` present if non-localhost targets are needed
- [ ] `.git/info/exclude` updated (git targets only)
- [ ] bishop-memory MCP registered in `opencode.json` (central mode only)

## Troubleshooting

- **Existing `opencode.json` conflict.** The installer backs up the existing file and stops. Re-run with `--force` to replace it, or merge the `agent` and `instructions` blocks manually.
- **No `rsync`.** The installer falls back to `cp -R` automatically, still skipping the runtime layer (`memory/`, `about/`, `bishop-memory.conf`).
- **Memory seed fails.** Ensure `.opencode/memory.zip` exists in the harness checkout. If it does not, the seed step is skipped; create `.opencode/memory/` by hand from the templates until the zip is available.
- **Memory nested as `.opencode/memory/memory/`.**
  - *Symptom:* the crew can't find `CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`, `DIRECTIVES.md` and the rest; they sit under `.opencode/memory/memory/state/` and so on.
  - *Cause:* earlier installers extracted `memory.zip` into `.opencode/memory/`, but the zip already has a top-level `memory/` folder.
  - *Fix:* re-run the fixed installer — it moves the contents up one level without overwriting anything and reports each move. Or move the five folders (`state`, `missions`, `workspace`, `findings`, `reference`) up one level by hand and delete the empty `.opencode/memory/memory/`. If both levels hold state files, the installer refuses; decide which copy is live and archive the other first.
- **Git still shows harness files as untracked.** That is expected. The installer uses `.git/info/exclude` so the harness files remain local-only.
