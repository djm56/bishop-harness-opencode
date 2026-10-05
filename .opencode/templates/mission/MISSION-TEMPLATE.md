# Mission Folder Scaffold

Creating `.opencode/memory/missions/mission-[id]/` means creating these two files, exactly as laid out below.

The `[id]` is always `mission-YYYYMMDD-NN` — the UTC creation date, then a counter that resets each day and starts at `01`. Bishop derives the ID and hands it over; the full derivation is in `.opencode/skills/mission-lifecycle/SKILL.md`. Nobody invents their own scheme.

## BRIEF.md

```markdown
# Brief — mission-[id]

## Goal
[one-line restatement from the Bishop brief]

## Acceptance Criteria
[bullet list]

## Key Files
[paths relevant to this mission]

## Notes
[constraints, prior attempts, or cross-agent context]
```

**Every path in `Key Files` is confirmed as it's written** — listed or read, not assumed. A path that doesn't exist yet gets an explicit `— to be created at step N` marker rather than being written bare. A wrong path in canonical mission state is invisible guidance: later agents take the documented structure as correct and nobody thinks to question it.

## DEBRIEF.md

Written at completion, never at mission start.

- Path: `.opencode/memory/missions/mission-[id]/DEBRIEF.md`
- Format comes from: `.opencode/templates/mission/DEBRIEF-TEMPLATE.md`
- What it's for: the end-to-end outcome, the assumptions that turned out wrong, the mistakes agents made, and whatever a similar mission later would want to know.

## PROGRESS.md

```markdown
# Progress — mission-[id]

| Step | Phase | Agent | Status | Notes |
|------|-------|-------|--------|-------|

<!-- Update row status after each sub-agent completes: pending → in-progress → done/failed -->
```

**Worth being clear about**: PROGRESS.md is both the canonical plan and the live step status. At mission start every planned step goes in as `pending`. A step becomes `in-progress` **the moment its brief is delegated** — not afterwards — and the state-sync that follows the step moves it to `done` (or `failed`). By the time a sync runs, the next step is already `in-progress`; the sync doesn't set it.

**The Phase column** groups steps under a phase or sub-phase label (`1.2`, `2.4 Part 3`, and so on). Unphased or single-phase missions use `—`. It's a required column either way, so a plan reads the same whether it has two steps or forty.
