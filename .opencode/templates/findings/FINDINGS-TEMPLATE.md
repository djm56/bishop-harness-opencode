# Finding Entry Formats

The reference for appending to the files in `.opencode/memory/findings/`.

**Append-only.** Existing entries are never modified, reordered, or deleted. New entries go on the end.

**Where the end is.** Every file in `findings/` carries the marker `<!-- Append new entries below this line -->` just under its header. The marker is written when the file is created and **never moved**. Every new entry goes **below it and below everything already there** — at the very bottom of the file. So the file reads oldest-first, growing downward, and nothing above the insertion point is ever touched.

Read the file before you write to it, find the last existing entry, and append after that. Never insert between entries, never rewrite the header or the marker, and never remove content to make room.

**Status.** Every new entry starts at `Status: proposed`. Only the human operator moves it along — `proposed → approved → applied`, with `rejected`, `retired`, and `superseded` as terminal branches. No agent, lambert (doc writer) included, ever changes the status on an existing entry, and no agent fills in `Approver` or `Date approved`.

---

## FINDINGS.md

File: `.opencode/memory/findings/FINDINGS.md`

This is the **findings ledger**: specific, observed findings, one entry per observation. It may cite code, paths, and symbols — that's what makes a finding checkable later.

```
### [YYYY-MM-DD] — [Agent/Skill/Tool Target]
**Suggestion**: [concrete, actionable change to an agent prompt, skill, or tool]
**Rationale**: [why this improves future mission outcomes]
**Status**: proposed
**Approver**: —
**Date approved**: —
```

Appended at the bottom of the file, below the marker and below every existing entry.

**Rules:**

- The target is a named agent (`@hicks`), a skill (`mission-lifecycle`), or a tool concept. Not a vague area.
- The suggestion has to be implementable without anyone coming back to ask what it means.
- Status is `proposed` on creation. Never anything else.
- **Approver** and **Date approved** belong to the human. No agent fills them in — they're recorded when a human moves status to `approved`.
- An entry may pick up amendment lines after `**Date approved**` — things like `**Disposition (mission-…):**` or `**Fold-forward (…):**`. So an entry ends at the next `### [` heading or at the end of the file, not at a fixed final field. Don't assume the last field you recognise is the end of the entry — and when appending, find the true bottom of the file rather than the first field you take for a terminator.
- This file is for agent, skill, and tool behaviour. Code patterns go in PATTERNS.md.
- When a finding turns out to generalise, a human ratifies the broader rule into `.opencode/memory/reference/DIRECTIVES.md` and marks the originating entry `applied`. Most findings don't generalise — one-offs stay in the ledger, and some are better fixed by editing the agent or skill directly.

---

## PATTERNS.md

File: `.opencode/memory/findings/PATTERNS.md`

```
### [Pattern Name]
**Context**: [when to use this pattern — specific trigger or situation]
**Solution**: [what to do]
**Example**: [brief code or reference, or "n/a" if not applicable]
**Discovered**: [YYYY-MM-DD, mission-id]
```

Appended at the bottom of the file, below the marker and below every existing entry.

**Rules:**

- Give it a short, descriptive name — something like `Bootstrap 4.3 SCSS Module Pattern`.
- Context is a concrete trigger, not a broad category.
- This file is for reusable solutions, architecture decisions, and technical approaches. Advisory and non-binding — `.opencode/memory/reference/DIRECTIVES.md` wins on any conflict.
- Agent and skill behaviour goes in FINDINGS.md, not here.

---

## service-records/[agent-name].md

File: `.opencode/memory/findings/service-records/[agent-name].md`

Create it if it isn't there yet, using the header below. The marker goes in at creation, sits under the header, and never moves — entries accumulate below it.

**Header for a new file — only when creating it, never repeated in an existing one:**

```markdown
# Agent Notes — [agent-name]

Calibration notes about this agent's performance, context needs, and framing.
Append only. Never modify existing entries.

<!-- Append new entries below this line -->
```

**Entry format** — appended at the bottom of the file, below the marker and below every existing entry:

```
### [YYYY-MM-DD] — [Observation Title]
**Note**: [what was observed — behavior, gap, missed step, or strength]
**Adjustment**: [what to change in future delegations or the agent's own file]
**Source**: self-reported | bishop-observed
```

**Rules:**

- `Source` is either `self-reported` (the agent wrote it about itself) or `bishop-observed` (Bishop added it from watching the delegation land).
- Write only when something is genuinely worth noting. No "no issues" or "performed as expected" entries — they're noise.
- The adjustment has to be specific enough to act on. "Add X to the pre-flight checklist in the agent file", not "be more careful".
- The marker stays where it is. A new note never displaces it, and never displaces an older note.
- A note is a record, not a licence to edit the agent. Agent and skill files are human-ratified: an agent that spots a hole in a definition records the proposal and surfaces it, and does not amend the definition mid-mission.
