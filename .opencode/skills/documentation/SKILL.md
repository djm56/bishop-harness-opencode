# Skill: documentation

# Documentation Writing

This skill defines how `lambert` produces and maintains documentation in the Bishop harness.

## Purpose

Documentation is a runtime dependency. If the crew cannot read how the system works, the system does not work. `lambert` owns the clarity, currency, and structure of every user-facing and crew-facing doc.

## Scope

`lambert` is responsible for:

- README files
- INSTALL and setup guides
- Changelogs
- Architecture decision records (ADRs)
- Runbooks and operational playbooks
- Crew state files (`CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`, `MISSION-ARCHIVE.md`, `DEBRIEF.md`)
- Skills and agent prompts when wording is the deliverable

`lambert` is **not** responsible for inline code comments — that belongs to the developer with review oversight from `apone`.

## Documentation principles

1. **Audience first.** Write for the reader, not the writer. A runbook for `bishop` during an incident reads differently from a README for a new operator.
2. **One source of truth.** Do not copy the same fact into two files. Link instead.
3. **Current or deleted.** Stale docs are worse than missing docs. If you cannot keep it current, remove it.
4. **Executable examples.** Commands in docs should be copy-pasteable and tested.
5. **Plain language.** Avoid jargon unless it is defined in the same file.

## File types

### README

- One per project or major component.
- States what it is, what it is not, how to install, and how to run a mission.
- Links to deeper docs rather than duplicating them.

### INSTALL

- Step-by-step setup.
- Prerequisites with version pinning.
- Troubleshooting section for the three most common failures.
- Layer-by-layer explanation of what gets installed where.

### Changelog

- Reverse-chronological.
- Each release lists added, changed, deprecated, removed, fixed, and security items.
- References mission IDs where applicable.

### ADR

- Numbered sequentially.
- Context, decision, consequences.
- Status: proposed / accepted / deprecated / superseded.

### Runbook

- Symptom → diagnosis → remediation → verification.
- Include rollback steps.
- State who should be notified.

## State-file style

Crew state files are machine-readable by humans:

- Use consistent headings.
- Use tables for structured data.
- Append-only where the skill requires it (`FLIGHT-RECORDER.md`).
- Never delete a mission archive entry; mark it superseded if needed.

## Review and approval

`lambert` writes docs; `apone` reviews them when they are part of a coding step. Technical accuracy is the developer's responsibility; clarity and structure are `lambert`'s.

## Updating docs with code

When a code change affects:

- A public API → update the README or API docs.
- Installation → update INSTALL.md.
- A decision → update or create an ADR.
- An operational procedure → update the runbook.
- A crew rule → update `AGENTS.md` or the relevant skill.

## Tools

`lambert` uses the task tool for doc-writing steps. When the deliverable is a state-file update, `lambert` may edit the file directly after reading the mission-lifecycle skill.

## See also

- `.opencode/skills/mission-lifecycle/SKILL.md` — state files and mission vocabulary.
- `.opencode/skills/code-documentation/SKILL.md` — docblock conventions.
- `AGENTS.md` — crew roles.
