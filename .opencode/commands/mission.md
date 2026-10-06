---
description: Frame and execute a structured mission with scope, plan, and crew assignments
agent: bishop
---

> **You are running as Bishop.** The primary agent executes this under `.opencode/agents/bishop.md`. Every piece of implementation goes out to a specialist through the **task tool**.

> **Full rules**: `.opencode/skills/mission-lifecycle/SKILL.md` covers every phase below in detail.

## ⚠️ THE EXECUTION LOOP — MANDATORY ⚠️

Every logical step in the plan runs through this exact sequence:

```
A. HAND the step to the named sub-agent.
   Set the step to `in-progress` in PROGRESS.md as part of handing it out.
   In the brief: "When done, end output with two lines:
   IMPROVEMENT-NOTE: none | <one concrete, actionable observation>
   STEP [N] COMPLETE — state-sync required before next step."

B. READ what comes back. Satisfy yourself the step is done.
   Non-`none` IMPROVEMENT-NOTE → it goes to
   `.opencode/memory/workspace/findings-scratch.md` (step, agent, note) as part of
   the same state-sync you hand out at C — never by your own hand, and never as
   a separate delegation.

C. HAND state-sync to @lambert (doc writer) straight away — in the SAME TURN as the
   step report. A sync promised in a closing sentence and left for the next
   turn counts as skipped.
   "State-sync for step [N]. Update PROGRESS.md (mark step [N] done),
   CURRENT-MISSION.md (Next Action — rewriting any sentence the intervening steps
   made untrue, not copying it forward), and append one FLIGHT-RECORDER.md row
   (event=step-sync, timestamp YYYY-MM-DD HH:MM UTC, read back and verified),
   and — where this step's IMPROVEMENT-NOTE was not `none` — append the note text
   verbatim to `.opencode/memory/workspace/findings-scratch.md`, formatted as
   `**Step [N] — @agent —** note`.
   Confirm the three state targets, the findings-scratch append or that the note
   was `none`, and the step number."

D. READ the confirmation — all three state targets, the findings-scratch append
   or an explicit statement that this step's note was `none`, the step number,
   and the FLIGHT-RECORDER row read-back.
   Missing or partial means the mission is BLOCKED. STOP.

E. ONLY THEN move to step N+1.
```

Nothing batched. Nothing deferred. No "I'll write it up at the end." Every step gets its own sync.

A step the operator injects mid-mission gets its `PROGRESS.md` row — `in-progress`, noted `(operator-directed, injected HH:MM UTC)` — **before** the work goes out, then runs A–E unchanged.

---

## PROGRESS.md Shape

At initialization, build both `BRIEF.md` and `PROGRESS.md` from `.opencode/templates/mission/MISSION-TEMPLATE.md`, copied exactly. Then fill `PROGRESS.md` with a row per planned step.

```markdown
# Progress — mission-[id]

| Step | Phase | Agent | Status | Notes |
|------|-------|-------|--------|-------|
| 1 | [phase or —] | @agent-name | pending | [description] |
| 2 | [phase or —] | @agent-name | pending | [description] |
```

Statuses run `pending` → `in-progress` → `done` | `failed`. A step becomes `in-progress` when its brief is delegated, not afterwards. `Phase` groups steps under a phase label; unphased missions use `—`.

---

## Running The Mission

1. Restate the goal and set out what "done" actually means.
2. Name the risks, dependencies, and assumptions you're working under.
3. Write a numbered plan. Every step names the sub-agent who owns it.
4. **Delegation constraint (mandatory):** every coding step goes to `@hicks` (junior developer). `@vasquez` (senior developer) never appears in an initial plan — it is reached only through the Code-Quality Pipeline, after two junior fix rounds. A plan that puts `@vasquez` on a coding step is INVALID; rewrite it. Every developer fix brief states its round index — `fix round 1 of 2` or `fix round 2 of 2` — and the review step it answers; the escalation brief to `@vasquez` names which trigger fired — see `.opencode/skills/mission-lifecycle/SKILL.md`, Rule 3, for the two trigger definitions — both `@apone` review step numbers, and the fix-round index reached. `@vasquez` gets two fix rounds under the same pipeline; still failing after both, the mission stops and goes to the operator.
   - **QA verification:** `@ripley` is a terminal, opt-in phase, canonical in `.opencode/skills/mission-lifecycle/SKILL.md` → QA Verification. She runs only after the final coding step and its paired `@apone` review, at most three passes, and is invoked either by the operator with `/qa` or by Bishop as the mission's final phase. A per-step Ripley slot in the middle of a plan is a process violation; stop and correct the plan.
5. Any step that writes or changes code is followed immediately by `@apone` (code reviewer). No exceptions.
6. Derive the mission ID yourself: `mission-YYYYMMDD-NN` — today's UTC date, plus a counter that resets daily. Take the highest `NN` already used for that date across both the `missions/mission-<date>-*` folders and the rows mentioning them in `FLIGHT-RECORDER.md` and `MISSION-ARCHIVE.md`, and add one; `01` if there are none. Folders get cleaned up, the logs don't — check both so an ID never comes back around. In central mode, allocate the ID via the `mission_allocate` MCP tool instead.
7. Hand mission initialization to `@lambert`, passing the derived ID: archive workspace (keep `.gitkeep` and `README.md`, move the rest to `archive-mission-[id]/`, recreate `findings-scratch.md`, return `ls -la` as evidence), build `BRIEF.md` and `PROGRESS.md` from `MISSION-TEMPLATE.md` exactly, initialize `CURRENT-MISSION`, confirm `FLIGHT-RECORDER.md` is present. **All five confirmed before step 1 runs.**
8. Agents may use `.opencode/memory/workspace/` as scratch space during execution. Preserve it when resuming an unfinished mission; clear it only on confirmed new-mission bootstrap, and clearing means archiving — nothing there is deleted.
9. Work the plan through the execution loop above.
10. Closing the mission — **in this exact order**. The tracker check, the learning pass, and `DEBRIEF` are prerequisites, not formalities:
    - Write a closing summary of what changed, for the operator.
    - **Tracker check (BLOCKING)**: diff every canonical tracker the mission touched against what's actually on disk. Drift either way — code with no completed step, or a tracker claiming work the disk doesn't have — is either synced before closing or recorded in `DEBRIEF.md` as not done / done but untracked / never in plan. When `@ripley` ran, also verify the QA verdict state: no open DEFECT without an operator decision (fixed and re-verified, or accepted and recorded), every DEVIATION either operator-accepted or sent back as a change order, and the `DEBRIEF.md` `QA Verdict` section reflecting the actual final pass results.
    - **Learning pass (BLOCKING)**: read `.opencode/memory/workspace/findings-scratch.md` — the notes collected as the steps ran — and add your own Bishop-level observations. Something concrete? Hand it to `@lambert` with named file targets and entry content, formatted per `.opencode/templates/findings/FINDINGS-TEMPLATE.md`. Nothing concrete? The pass is done; write nothing.
    - **Then, and only then, create `missions/mission-[id]/DEBRIEF.md` (BLOCKING)** via `@lambert`, from `.opencode/templates/mission/DEBRIEF-TEMPLATE.md`. Get confirmation that the mandatory sections are there — "Wrong Assumptions" and "Sub-Agent Mistakes and Corrections". The completion gate in `.opencode/mission-guard.ts` refuses to let the mission close without this file.
    - Only after the report exists: mark `CURRENT-MISSION.md` complete.
    - Only after that: append one `FLIGHT-RECORDER.md` row with event `complete`, read back and verified.
    - Only after that: append one `MISSION-ARCHIVE.md` row at the end (append-only, columns exactly `Mission ID | Completed | Outcome | Summary`, outcome `done|failed`). Enforcement detail is in `.opencode/skills/mission-lifecycle/SKILL.md`.
    - **If you break the order** — marking complete, appending `MISSION-ARCHIVE`, or skipping the report before the tracker check, the learning pass, and `DEBRIEF` have run — the mission is not done. **Break it a second way** — appending `MISSION-ARCHIVE` before the `FLIGHT-RECORDER` complete row — and the journal and `MISSION-ARCHIVE` disagree about whether the mission ever closed. Go back and run them.

Keep the output tight and ready to act on.

Start a new mission for this project from the following request:
$ARGUMENTS
