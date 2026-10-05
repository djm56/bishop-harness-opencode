# Bishop Harness for opencode

A small, opinionated mission harness for [opencode](https://opencode.ai). One commander — **Bishop** — routes every task through a crew of specialist agents. Bishop never writes code; the crew does, in a fixed order, with a fixed review gate.

> **What this is:** portable doctrine and runtime scaffolding. Drop it into a project, run the install script, and you have a `.opencode/` tree plus the root files opencode needs to load the crew.
>
> **What this is not:** a general-purpose agent framework. The rules are deliberately tight.

## The crew

| Agent | Role | Mode | Model |
|---|---|---|---|
| `bishop` | Commander | primary | `opencode-go/glm-5.2` |
| `hicks` | Junior developer | subagent | `opencode-go/kimi-k2.7-code` |
| `apone` | Code reviewer | subagent | `opencode-go-minimax/qwen3.7-plus` |
| `vasquez` | Senior developer | subagent | `opencode-go/kimi-k2.6` |
| `lambert` | Documentation writer | subagent | `opencode-go/hy3` |

- **Bishop** plans, delegates, reviews and closes. Bishop does not edit product files or run deploy commands.
- **Hicks** is the only coder in the initial plan. Every coding step goes to hicks.
- **Apone** follows every coding step immediately and reviews the diff.
- **Vasquez** is escalation-only. After two failed junior fix rounds, Bishop hands the mission to vasquez.
- **Lambert** owns documentation and all state-file updates.

The full wiring, delegation constraints, and memory layout are in [CREW-MANIFEST.md](./CREW-MANIFEST.md) and [AGENTS.md](./AGENTS.md).

## What you need

- [opencode](https://opencode.ai) installed and on your `PATH`.
- A project you want to run missions in.

## Install the harness into a project

From this repo:

```bash
./install-harness.sh /path/to/target-project
```

The script copies the portable layer (`.opencode/`, `AGENTS.md`, `SOUL.md`, `CREW-MANIFEST.md`, `opencode.json`) into the target, seeds `.opencode/memory/` from the packaged `memory.zip` when present (the zip is built and shipped in a later packaging step), and appends the harness paths to the target's `.git/info/exclude` so the runtime files stay out of the product repo.

See [INSTALL.md](./INSTALL.md) for manual install steps and layer-by-layer explanation.

## Running a mission

Open the target project in opencode and start with a mission objective. Bishop will frame the work, write a numbered plan, and hand each step to the right crew member.

The mission vocabulary is intentional:

- `CURRENT-MISSION.md` — the live pointer to the active mission.
- `FLIGHT-RECORDER.md` — append-only audit journal of state changes.
- `MISSION-ARCHIVE.md` — index of completed missions.
- `missions/mission-YYYYMMDD-NN/` — per-mission folder with `BRIEF.md`, `PROGRESS.md`, and, at close, `DEBRIEF.md`.
- `.opencode/memory/findings/` — findings ledger (`FINDINGS.md`), advisory patterns (`PATTERNS.md`), and service records.
- `.opencode/memory/reference/DIRECTIVES.md` — binding, human-ratified rules.

A mission is not marked complete until `DEBRIEF.md` contains the `Wrong Assumptions` and `Sub-Agent Mistakes` sections.

## Shared central memory (optional)

The harness can use a local `bishop-memory` service (`memoryd` on `http://127.0.0.1:8787`) for shared, searchable mission state across multiple projects.

- Standalone mode is the default: everything stays in `.opencode/memory/`.
- Central mode requires `.opencode/bishop-memory.conf` and running `.opencode/connect-bishop-memory.sh` to register the `mcpd` adapter in `opencode.json`.

See [AGENTS.md](./AGENTS.md) for the full bishop-memory doctrine and the intended MCP tool surface.

## Updating the harness

Re-run `install-harness.sh` in the target project. By default the script will not overwrite an existing harness unless you pass `--force`. Use `--dry-run` to preview changes.

## Troubleshooting

- **opencode does not see the agents.** Check that `opencode.json` is in the project root and that the `agent` block points at files that exist under `.opencode/agents/`.
- **Memory folder is missing.** The installer seeds it from `.opencode/memory.zip`. If you delete `.opencode/memory/`, extract the zip again before starting work.
- **Central mode is not connecting.** Confirm `memoryd` is running (`curl http://127.0.0.1:8787/healthz`), that `.opencode/bishop-memory.conf` sets `BISHOP_MEMORY_MODE=central`, and that you ran `.opencode/connect-bishop-memory.sh` and restarted opencode.
