---
name: self-improvement
description: "Framework for capturing high-quality findings and learnings discovered during mission execution. Covers identifying valuable patterns, edge cases, architecture insights, and directives that should update agent prompts or skills. Used by Bishop to suggest enhancements without creating excessive noise."
---

# Learning From Finished Work

## When It Runs

The learning pass is **mandatory at the end of every mission**. Bishop runs it whether or not it produces anything. Entries get written only where there's something concrete and actionable — never to prove the pass happened.

- Sub-agents attach findings to their step completion report, **only when they actually found something**. Saying nothing is a valid outcome.
- Bishop gathers those reports plus its own observations once the mission is done.
- Where something concrete exists, Bishop hands the writes to `@lambert` (doc writer), pointing at `.opencode/templates/findings/FINDINGS-TEMPLATE.md` for format.
- `@lambert` does the appending. Bishop never writes these files directly.

## How It Flows

```
Sub-agent finishes a step
  └─ Attaches an improvement note to its completion report (only if it found something)
       └─ Bishop collects reports as the mission runs
            └─ At completion, Bishop reviews everything collected plus its own observations
                 └─ Anything concrete?
                      └─ Bishop delegates the writes to @lambert
                           └─ @lambert appends, using FINDINGS-TEMPLATE.md
```

- A sub-agent with nothing to report says nothing. No "no issues here" message needed.
- Bishop decides what qualifies before delegating anything.
- `@lambert` gets named files and exact content. It doesn't decide what's worth recording.
- Everything is created as `proposed`. Only the human operator moves it on.

## The Bar An Entry Has To Clear

Before writing anything, ask:

1. Is it specific enough to act on? If not, drop it.
2. Is it worth doing, even if the payoff is small? Vague or hypothetical, drop it.
3. Is it already covered by an agent prompt or a skill? If yes, drop it.
4. Could someone implement it without coming back to ask questions? If not, sharpen it first.

## Where Things Go

Everything lands under `.opencode/memory/findings/`, sorted by what kind of insight it is:

| Kind of insight | Goes to |
|---|---|
| Reusable pattern (architecture, naming convention, test strategy) | `.opencode/memory/findings/PATTERNS.md` |
| A specific observed finding — a change to an agent, skill, or tool | `.opencode/memory/findings/FINDINGS.md` |
| How a particular agent is performing | `.opencode/memory/findings/service-records/<agent-name>.md` |
| Scratch collection while the mission is still running | `.opencode/memory/workspace/findings-scratch.md` |

Nothing here is written from memory at the end. Non-`none` IMPROVEMENT-NOTE footers get appended to `findings-scratch.md` as the steps land, and the closing pass consolidates that list. The scratch file is archived at the next new-mission init like anything else in `workspace/`.

**Format authority**: `.opencode/templates/findings/FINDINGS-TEMPLATE.md` governs all three. Every file is append-only, and every one of them carries `<!-- Append new entries below this line -->` under its header — new entries go below that marker and below every existing entry, at the very bottom of the file. The marker never moves and nothing already written is displaced.

> **A directive is not a finding.** `.opencode/memory/reference/DIRECTIVES.md` holds binding rules a human ratified, and it sits OUTSIDE this framework — no agent writes to it. If an insight ought to become a hard rule, file it here as a `FINDINGS.md` suggestion (status `proposed`) and let a human ratify it across. On conflict, `DIRECTIVES.md` (binding) beats `PATTERNS.md` (advisory).

### FINDINGS.md

Proposed changes to an agent prompt or a skill file.

```
### [Date] — [Agent/Skill/Tool Target]
**Suggestion**: [concrete change]
**Rationale**: [why this improves outcomes]
**Mission**: [mission-YYYYMMDD-NN]
**Status**: proposed
**Approver**: —
**Date approved**: —
```

This is the findings ledger: one entry per observation, specific enough to cite code, paths, and symbols. `Status`, `Approver`, and `Date approved` belong to the human operator — an agent writes `proposed` and dashes, and never touches them again.

### PATTERNS.md

Architectural patterns, conventions, or solutions worth reusing.

```
### [Pattern Name]
**Context**: [when to use this]
**Solution**: [what to do]
**Example**: [brief code or reference]
**Discovered**: [date, mission-id]
```

### service-records/[agent-name].md

How a given agent is doing — performance, the context it needs, how briefs land. Written by the agent about itself (self-reported) or by Bishop from observation. Both count.

```
### [Date] — [Observation]
**Note**: [what was observed]
**Adjustment**: [what to change in future delegations]
**Source**: self-reported | bishop-observed
```

## Worked Examples

**FINDINGS.md**

```
### 2026-05-04 — vasquez
**Suggestion**: Add a pre-flight checklist to the agent file: before starting block development, verify ACF config, check component lifecycle, confirm Bootstrap 4.3 constraints.
**Rationale**: These constraints tend to surface halfway through implementation. Checking first moves the discovery earlier and cuts rework.
**Status**: approved
```

**PATTERNS.md**

```
### Bootstrap 4.3 SCSS Module Pattern
**Context**: Styling responsive layouts with Bootstrap 4.3, where inline @media queries spread quickly.
**Solution**: Use the media-breakpoint-up() mixin. One .scss module per component, BEM naming: .b-[component]__[element]--[modifier].
**Example**: .b-hero__content { font-size: 1rem; @include media-breakpoint-up(lg) { font-size: 1.5rem; } }
**Discovered**: 2026-04-25, mission-20260425-01
```

---

## How Status Moves

1. **proposed** — newly raised, nobody has looked yet.
2. **approved** — reviewed and accepted.
3. **applied** — actually implemented in the target agent prompt or skill file, or generalised into a ratified `DIRECTIVES.md` entry.
4. **rejected** — reviewed and turned down, with the reason written down.

`retired` and `superseded` are the other terminal states, for an entry overtaken by events or replaced by a later one. Every transition is the human operator's; no agent moves a status.

## When The Same Finding Keeps Coming Back

Three or more entries saying the same thing is not a ledger problem. It means an agent or skill definition has a hole in it, and the fix belongs there rather than in a fourth entry.

That fix is a **proposal, not an edit**. Agent and skill definitions are human-ratified, exactly like `DIRECTIVES.md`: record the proposal, put it in front of the operator, and leave the definition alone until they ratify it.

## What Not To Write

- Nothing vague. "Agent did well" and "could be better" help no one.
- Nothing already sitting in an agent prompt or skill.
- Nothing hollow. No "no learnings this mission" entries. If nothing clears the bar, write nothing at all — that's the correct outcome, not a gap.
