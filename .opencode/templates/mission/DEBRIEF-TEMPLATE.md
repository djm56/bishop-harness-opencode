# The Debrief

Written to `.opencode/memory/missions/mission-[id]/DEBRIEF.md` when a mission closes.

- Written once, at the closing gate. It's a single-write artifact.
- Not a rolling log — don't keep adding to it across sessions.
- Not a replacement for `MISSION-ARCHIVE.md`, which stays the append-only index.

## DEBRIEF.md

```markdown
# Debrief — mission-[id]

## Mission Summary
- Goal: [one-line goal from BRIEF.md]
- Outcome: done | failed
- Completed: YYYY-MM-DD HH:MM UTC

## Acceptance Criteria Outcome
- [ ] [criterion 1] — pass | fail | partial
- [ ] [criterion 2] — pass | fail | partial

## Logical Step Recap
| Step | Phase | Agent | Status | Notes |
|------|-------|-------|--------|-------|
| 1 | [phase or —] | @agent-name | done | [summary from PROGRESS.md] |
| 2 | [phase or —] | @agent-name | done | [summary from PROGRESS.md] |

## Deliverables Changed
- `path/to/file.ext` — [what changed and why]
- `path/to/another.ext` — [what changed and why]

## Tracker And Reality
- Trackers checked: [project progress.md, README status table, …] | none touched
- Drift found: none | [what disagreed with the disk]
- Resolution: tracker synced before closing | drift recorded here as
  not done / done but untracked / never in plan

## Wrong Assumptions (Mandatory)
| Assumption | Why It Was Wrong | Correction Applied |
|------------|------------------|--------------------|
| [assumption] | [evidence/outcome] | [fix/process change] |

## Sub-Agent Mistakes and Corrections (Mandatory)
| Agent | Mistake | Impact | Corrective Action | Prevention Next Time |
|-------|---------|--------|-------------------|----------------------|
| @agent-name | [what went wrong] | [low/med/high + brief note] | [what was done] | [specific safeguard] |

## QA Verdict
- QA phase: not run | run — passes: QA pass — initial[, QA re-verify 1 of 2][, QA re-verify 2 of 2]

| Pass | Verdict summary | Evidence folder |
|------|-----------------|-----------------|
| QA pass — initial | [DEFECT n / DEVIATION n / OBSERVATION n / PASS] | `.opencode/memory/workspace/qa/<run-id>/` |

- Operator decisions: [each DEVIATION accepted or sent back; any DEFECT risk accepted] | none
- Unverified: [items and why] | none
- Needs human review: [items] | none

Note: write "not run" when the QA phase wasn't invoked for this mission. Ripley's grades are recorded as she gave them; this section never regrades them.

## Findings and Patterns Linked
- Findings entry refs: [FINDINGS.md heading] | none
- Pattern entry refs: [PATTERNS.md heading] | none
- Agent notes refs: [service-records/<name>.md heading] | none

## Similar Future Missions
- Trigger to reuse this report: [when a future mission is similar]
- Reuse checklist:
  1. [step]
  2. [step]
  3. [step]
```

**On Tracker And Reality**: the three drift labels are the ones defined in `.opencode/skills/mission-lifecycle/SKILL.md` under Three Kinds Of Not Done. Use them as written — they carry different fixes, and collapsing them into "not started" loses the only information that says which fix applies.
