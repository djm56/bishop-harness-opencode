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
3. Seeds `.opencode/memory/` from `.opencode/memory.zip` when present (the zip is built and shipped in a later packaging step). Skipped if memory already exists; use `--force` to re-seed.
4. Appends the harness paths to `.git/info/exclude` so runtime files stay out of the product repo.
5. Reports what was copied and what to do next.

## Flags

- `--dry-run` — show what would be copied, but change nothing.
- `--force` — overwrite existing harness files and re-seed memory even if they already exist.
- `--help` — show usage.

## Manual install

If you prefer not to run the script:

1. Copy the portable root files into the target project:
   - `AGENTS.md`
   - `SOUL.md`
   - `CREW-MANIFEST.md`
   - `opencode.json`
2. Copy the portable `.opencode/` tree into the target project.
3. Extract `.opencode/memory.zip` into `.opencode/memory/`.
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

- Check that opencode loads the root `AGENTS.md` and `SOUL.md` as instructions.
- Confirm the agents listed in `opencode.json` match the files under `.opencode/agents/`.
- Start a mission by describing the objective to `bishop`.

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
2. Copy `.opencode/bishop-memory.conf.example` to `.opencode/bishop-memory.conf` and set `BISHOP_MEMORY_MODE=central` and a unique `BISHOP_HARNESS` name.
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
- [ ] `.opencode/agents/ripley.md`
- [ ] Playwright MCP registered in `opencode.json` `mcp` block
- [ ] `.opencode/qa-guard.ts` listed in `opencode.json` `plugin` array
- [ ] `.opencode/qa.conf` present if non-localhost targets are needed
- [ ] `.git/info/exclude` updated

## Troubleshooting

- **Existing `opencode.json` conflict.** The installer backs up the existing file and stops. Re-run with `--force` to replace it, or merge the `agent` and `instructions` blocks manually.
- **No `rsync`.** The installer falls back to `cp -R` automatically.
- **Memory seed fails.** Ensure `.opencode/memory.zip` exists in the harness checkout. If it does not, the seed step is skipped; create `.opencode/memory/` by hand from the templates until the zip is available.
- **Git still shows harness files as untracked.** That is expected. The installer uses `.git/info/exclude` so the harness files remain local-only.
