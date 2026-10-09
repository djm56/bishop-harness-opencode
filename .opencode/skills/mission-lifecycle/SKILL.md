---
name: mission-lifecycle
description: "Single canonical source of truth for how missions flow through the system. Covers mission IDs, the state-update contract, agent delegation rules, the code-quality pipeline, and findings/learning. Referenced by bishop, commands, and the doc writer (lambert)."
---

# The Mission Lifecycle

This is the **one canonical reference** for how missions run. Where any other document disagrees with this file, this file wins.

Every agent and command that does work follows what's below.

---

## What This Covers

The full lifecycle — the `/mission` path that `@bishop` drives. It applies to every mission the harness runs: durable session state (`CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`, `MISSION-ARCHIVE.md`, `missions/mission-[id]/`), a sync after every step, and the learning pass at the end. The **Delegation Contract** below rides along with it: junior starts all implementation, reviewer checks every step, senior stays in reserve.

---

## Terms

- **Logical plan step** — a numbered step in Bishop's plan. One step is one delegation to one sub-agent (e.g. "Step 2: @hicks — implement feature X").
- **State-sync delegation** — the required checkpoint handed to @lambert (doc writer) right after each logical step. It may go unnumbered in the written plan, but it is never optional at runtime. It is not itself a numbered step: it takes no sync of its own, and its sign-off reads `STATE-SYNC [N] COMPLETE`, where `[N]` is the step being synced. Its own IMPROVEMENT-NOTE is carried by the next step's sync.
- **Code-producing step** — any step that creates or changes files outside `.opencode/`.

### Three Kinds Of Not Done

When you check a tracker against what's actually on disk, three different things look identical if you file them all as "not started". Name them apart:

- **not done** — planned, then deferred or never begun.
- **done but untracked** — the step finished and the code is there, but its state-sync never happened. A gap in the ceremony, not in the work.
- **never in plan** — code on disk with no step in `PROGRESS.md` or `BRIEF.md` that accounts for it. Delivery nobody recorded.

The three have different fixes. Collapsing them into one label loses the only information that tells you which fix applies.

---

## Mission IDs

Every `/mission` run gets its own ID, shaped **`mission-YYYYMMDD-NN`**:

- `YYYYMMDD` — the day the mission was created, in **UTC**. Same clock as the timestamps in `FLIGHT-RECORDER.md` and `MISSION-ARCHIVE.md`, so nothing has to be converted to work out the sequence.
- `NN` — a zero-padded counter **scoped to that UTC day**. Starts at `01`, goes up by one per mission created that day, and resets to `01` when the UTC date rolls over.

So: `mission-20260711-01` → `mission-20260711-02` (same UTC day) → `mission-20260712-01` (next day, reset).

### Working Out The Next One

Bishop derives the ID before delegating anything, and does it deterministically:

1. `date` = today's UTC date as `YYYYMMDD`.
2. Find the highest `NN` already taken for `date`, looking at **both**:
   - folders matching `.opencode/memory/missions/mission-<date>-*`, and
   - rows mentioning `mission-<date>-*` in `.opencode/memory/state/FLIGHT-RECORDER.md` and `.opencode/memory/state/MISSION-ARCHIVE.md`.
3. `NN` = highest found + 1. Nothing found for `date` means `NN` = `01`. Zero-pad to two digits.

**Why both places.** Stale-mission cleanup deletes finished mission folders, but `FLIGHT-RECORDER.md` and `MISSION-ARCHIVE.md` are append-only and keep the record. Checking the logs as well as the folders is what guarantees a retired ID never comes back around — a reused ID makes the audit trail ambiguous, which is the one thing the journal exists to prevent. On a day that somehow passes 99 missions, carry on with three digits (`100`, `101`, …).

The ID belongs to Bishop, not to the agent creating the folder. Nobody invents their own scheme.

### Central Mode — When bishop-memory Owns The ID

Which route applies is decided by `.opencode/bishop-memory.conf` at the project root. Read it before deriving anything.

- **No file, or `BISHOP_MEMORY_MODE=standalone`** — derive the ID locally exactly as described above. Nothing else changes and bishop-memory need not be running.
- **`BISHOP_MEMORY_MODE=central`** — the ID is allocated, not derived. Call the `mission_allocate` MCP tool with the mission `title`. It returns the ID and registers the mission in one atomic operation, which is what makes duplication impossible: the row holding the ID is created in the same transaction that computed it. The owning harness comes from the project-scope MCP registration, so it does not need passing.
- **If bishop-memory is unreachable in central mode, stop and tell the operator. Never fall back to local derivation.** State the reason plainly: local derivation is right for one harness and wrong for several — two harnesses both compute the same `NN` — and a reused ID in an append-only journal is not recoverable. A blocked mission start is recoverable; a duplicate ID in an append-only journal is not.

**Central mode carries two obligations.** The ID is allocated at mission start via `mission_allocate`. The reconciler runs at mission close. Between them, `.opencode/mission-guard.ts` mirrors journal rows continuously. Everything else — mission steps, findings, patterns, service records — reaches the service through the reconciler at mission close (step 10 of the Closing Checklist below), which brings every structured table into line with the Markdown truth.


---

## The State-Sync Contract

### Who Does What

- **Bishop** decides what changed and what happens next.
- **@lambert** does the writing, on Bishop's delegation.
- @lambert updates all three state files (`PROGRESS.md`, `CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`) — plus `findings-scratch.md` where the step's IMPROVEMENT-NOTE wasn't `none` — in **one delegation**, never as separate ones.

### The Sync Targets

Every sync touches three mandatory targets, plus a conditional fourth:

| File | What changes |
|------|--------------|
| `.opencode/memory/state/FLIGHT-RECORDER.md` | One appended row — the primary continuity record: Timestamp | Mission ID | Step | Agent | Event | Note. Event is `step-sync`. This row is the authoritative record that the sync happened. |
| `.opencode/memory/state/CURRENT-MISSION.md` | The live pointer: mission id, status, owner, next action, last-updated timestamp, blockers. |
| `.opencode/memory/missions/mission-[id]/PROGRESS.md` | The finished step marked done. The plan and its live status live here. |
| `.opencode/memory/workspace/findings-scratch.md` | Conditional. Where the step's IMPROVEMENT-NOTE was not `none`, the note appended verbatim as `**Step [N] — @agent —** note`. Nothing to append when the note was `none`, and the sync confirmation says which. |

### The Audit Journal

`.opencode/memory/state/FLIGHT-RECORDER.md` is the primary continuity record and the source of truth for a mission's history. One row per state-sync delegation. Schema is in `.opencode/templates/state/STATE-FILE-TEMPLATE.md` — Timestamp | Mission ID | Step | Agent | Event | Note. Event is `step-sync`, timestamp is the moment of the sync in `YYYY-MM-DD HH:MM UTC`, Note carries brief context. It isn't a side note; it's the record.

### Checking The Row You Just Wrote

A corrupt journal row is worse than a missing one — it reads as history. So after appending to `FLIGHT-RECORDER.md`, @lambert re-reads the row it just wrote and confirms four things:

1. **Both pipes are there.** The row starts with `|` and ends with `|`. A row missing its leading or trailing pipe isn't a table row at all, and counting cells will not catch it.
2. **Exactly six cells.** Split on `|` and count: Timestamp, Mission ID, Step, Agent, Event, Note. More than six means an unescaped `|` got into the Note and split the cell. Fix it now.
3. **The timestamp is whole.** Exactly `YYYY-MM-DD HH:MM UTC`, 24-hour. A bare date with no time (`2026-07-24 UTC`) is invalid. Never invent a time, never estimate one, never carry one forward from earlier in the conversation — a fabricated timestamp in an audit journal does more damage than a visible gap.
4. **Time moves forward.** The new row's timestamp is greater than or equal to the row above it. If it's earlier, the row was inserted into the middle of the file rather than appended, and the journal's ordering — the only thing making it a journal — is broken.

That check is reported as part of the sync confirmation. A failed check gets corrected and re-verified before the sync is called done.

**One tool constraint.** Append the row with Write or Edit — never a shell heredoc. A heredoc writes `\|` as a literal backslash followed by a pipe, which defeats the escape, splits the cell, and produces exactly the corruption the escape existed to stop.

### Timing

| Trigger | What happens |
|---------|--------------|
| **Mission start** — before step 1 of a genuinely new mission | Build `missions/mission-[id]/BRIEF.md` and `PROGRESS.md` from `.opencode/templates/mission/MISSION-TEMPLATE.md`, copied exactly — same headings, order, structure. Fill in the planned-step rows in `PROGRESS.md`; the plan lives there. Initialize `CURRENT-MISSION.md` with the new mission id and status `in-progress`. Confirm `FLIGHT-RECORDER.md` exists. Clear `.opencode/memory/workspace/` — but only once you've confirmed the previous mission is complete or deliberately replaced, and clear it in the sense defined under The Scratch Workspace below: archive, don't delete. |
| **After EVERY numbered step** | Hand a state-sync to @lambert: append the FLIGHT-RECORDER.md row, update the CURRENT-MISSION.md pointer, mark the step done in PROGRESS.md, and — where the step's IMPROVEMENT-NOTE wasn't `none` — append it to `findings-scratch.md`. Three mandatory targets plus the conditional fourth, one delegation. Mandatory — and handed over **in the same turn as the step report that triggered it**. A sync mentioned in a closing sentence and left for the next turn has been skipped, not started. The step went to `in-progress` when its brief was delegated; the sync is what marks it `done`. |
| **Operator-injected step** — scope the operator adds mid-mission | The PROGRESS.md row goes in **before** the work is delegated: status `in-progress`, note `(operator-directed, injected HH:MM UTC)`. From there it takes the same per-step sync as anything else. A row backfilled afterwards is a record repaired rather than a record kept — for the whole time the work was in flight, the state on disk didn't mention it. Urgency is the reason to write the row, not the excuse for skipping it; it costs one delegation. |
| **Bishop-injected step** — a cleanup, correction, or remediation Bishop orders, including work arising from the closing tracker check | The PROGRESS.md row goes in **before** the work is delegated: status `in-progress`, note `(bishop-directed, injected HH:MM UTC)`. From there it takes the same per-step sync as anything else. This applies after the final numbered step as much as during the plan — remediation found by the closing tracker check is a step, and the plan grows by one. A deliverable changed with no row and no sync row is the unrecorded work that check exists to catch. |
| **Step resumed mid-flight** — picked up from an agent's transcript rather than restarted | The resuming agent opens with a state report saying what it had and hadn't written to disk before the interruption. The step isn't synced done until that report exists, or the next step has to work it out from scratch. |
| **Mission completion** — after the final step | Run the learning pass (BLOCKING). Only then set `CURRENT-MISSION.md` to complete. Only then append to `MISSION-ARCHIVE.md`. |

### The Sync Rewrites; It Doesn't Copy

The CURRENT-MISSION.md update is a rewrite of what has stopped being true, not a transcription of the previous version with a new timestamp.

Any sentence anywhere in the file describing something as outstanding, pending, awaiting a decision, or blocked gets re-checked against what the intervening steps actually did, and rewritten or removed where they closed it. Finishing the work does not update the sentence calling it unfinished. A sentence carried forward unchanged invites the next reader to re-decide something already settled — and because it sits in the state file, it reads as authoritative while being wrong. Say so in the sync delegation, so the receiver performs the re-check instead of copying the text.

### The Scratch Workspace

- During a mission, any agent may create, update, edit, delete, and organise files under `.opencode/memory/workspace/`.
- The structure inside it is deliberately unconstrained.
- It's temporary and scoped to the mission: drafts, checklists, scratch notes, analysis, review write-ups while work is in flight.
- When the active mission is `in-progress` or `blocked`, everything in there survives across sessions and counts as valid context on resume.
- The canonical files stay canonical regardless: `PROGRESS.md` (plan and step status), `CURRENT-MISSION.md` (live pointer), `FLIGHT-RECORDER.md` (continuity record).
- Clearing happens only at confirmed new-mission initialization, and **clearing means archiving**: keep `.gitkeep` and `README.md` in place, **move** every other `.md` file into `.opencode/memory/workspace/archive-mission-[id]/`, then recreate `findings-scratch.md` with a fresh header. Nothing is deleted — a workspace file is sometimes the only copy of a deliverable that never shipped. The evidence that this ran is the `ls -la` of the directory afterwards, returned with the confirmation. A claim on its own doesn't satisfy it.

### Where Things Live

Putting a file in the wrong directory breaks the contract. The mapping:

| Artifact | Where it goes |
|----------|---------------|
| Session checkpoints, handoff notes, scratch analysis, review drafts, `findings-scratch.md` | `.opencode/memory/workspace/` — temporary, archived at new-mission init |
| Live pointer, audit journal, finished-mission index | `.opencode/memory/state/` — **only** `CURRENT-MISSION.md`, `FLIGHT-RECORDER.md`, `MISSION-ARCHIVE.md` |
| Mission plan and status, context, completion report | `.opencode/memory/missions/mission-[id]/` — `PROGRESS.md`, `BRIEF.md`, `DEBRIEF.md` |
| Findings, patterns, agent calibration notes | `.opencode/memory/findings/` — `FINDINGS.md`, `PATTERNS.md`, `service-records/<name>.md` |
| Binding human-ratified directives | `.opencode/memory/reference/DIRECTIVES.md` — human-edited only |

- **`state/` is a closed directory.** The three canonical state files, plus machine-written harness state produced by `.opencode/mission-guard.ts`. Nothing else, ever — no checkpoints, session notes, drafts, or reports. An agent cannot bring a file into scope simply by writing it there. The full allowlist is in `.opencode/templates/state/STATE-FILE-TEMPLATE.md`. A checkpoint or handoff note belongs in `workspace/`, referenced from the active mission's `BRIEF.md` so resume can find it.
- **Rules never live inside the folder they describe.** How the system works belongs in agents, skills, and templates. A doctrine file written into `memory/` — `workspace/` especially — gets archived at the next mission init, and the rule goes with it.

### The Rule

> When a numbered step finishes, Bishop delegates a state-sync to @lambert in the same turn as the step report, and before calling the next sub-agent. No exceptions, no batching, no skipping, no saving it for the end, and no leaving it for the next turn.

If Bishop can't open a state file and see the current position in the plan, the contract is already broken.

### The Blocking Gate

- Bishop does not delegate the next step until the sync has succeeded.
- A sync that's missing, partial, malformed, or stale sets the mission to `blocked` and stops execution until it's fixed.
- One catch-up write at the end does not retroactively satisfy the syncs that were skipped.

### Validating A Sync

All of this has to hold before execution continues:

1. FLIGHT-RECORDER.md row appended (event=step-sync), matching the STATE-FILE-TEMPLATE schema: Timestamp | Mission ID | Step | Agent | Event | Note — and passing the four post-write checks above.
2. CURRENT-MISSION.md updated — mission id, status, owner, next action, last-updated (`YYYY-MM-DD HH:MM UTC`), blockers — with stale prose rewritten rather than carried forward.
3. PROGRESS.md step table — the finished step marked `done`. The next step is already `in-progress`; it was set that way when its brief went out.
4. All three conform to `.opencode/templates/state/STATE-FILE-TEMPLATE.md` and `.opencode/templates/mission/MISSION-TEMPLATE.md`.
5. The sync describes the step immediately preceding it, and nothing else.
6. Where the step's IMPROVEMENT-NOTE was not `none`, it has been appended to `.opencode/memory/workspace/findings-scratch.md` in this same delegation, and the confirmation says so.

### The Sync-Evidence Gate

- Closing actions (`CURRENT-MISSION complete`, `MISSION-ARCHIVE`) are only permitted once every logical step has sync evidence behind it.
- A step without that evidence makes completion invalid. The mission stays `in-progress` or `blocked`.

### Appending To MISSION-ARCHIVE

- Append-only.
- One new row at the end for the finished mission.
- Existing rows are never modified.
- The header and separator rows are never rewritten.
- Exactly this shape and column order:

```markdown
| Mission ID  | Completed        | Outcome | Summary                                                              |
|-------------|------------------|---------|----------------------------------------------------------------------|
| mission-[id] | YYYY-MM-DD HH:MM UTC | done|failed | [concise summary]                                                   |
```

---

## Where The Schemas Live

State files follow `.opencode/templates/state/STATE-FILE-TEMPLATE.md`. That's the schema reference. This skill says *when* and *why* to write; the template says *what the file looks like*.

Mission files follow `.opencode/templates/mission/MISSION-TEMPLATE.md` for `BRIEF.md` and `PROGRESS.md`.

Human-ratified directives live in `.opencode/memory/reference/DIRECTIVES.md`, scaffolded by `.opencode/templates/reference/DIRECTIVES-TEMPLATE.md`. Binding, and human-edited only — see the Directives Contract below.

---

## The Delegation Contract — Not Negotiable

Who gets coding work. Applies while planning *and* while executing. Bishop enforces it.

### Rule 1 — @hicks starts everything

- Every coding implementation step in the plan goes to `@hicks` (junior developer).
- `@vasquez` (senior developer) gets no step in the initial plan.
- True regardless of how complex, architectural, performance-critical, or difficult the mission looks.
- No exceptions. Complexity is handled by scoping the mission, not by picking a different agent.

### Rule 2 — @apone follows every coding step

- Wherever `@hicks` or `@vasquez` writes or changes code, the **very next numbered step** is `@apone` (code reviewer).
- "Very next" means nothing in between. The review sits directly behind the code.
- Fix rounds included — every fix attempt by any developer gets its own review step.

### Rule 3 — @vasquez only by escalation

- `@vasquez` arrives through the Code-Quality Pipeline below, and no other way.
- Bishop escalates when **either** trigger fires, whichever comes first:
  - **Severity trigger** — the same CRITICAL finding is still open after two junior fix rounds, confirmed by two separate `@apone` reviews. Counted **per issue**.
  - **Round trigger** — `@hicks` has completed two fix rounds on this mission, whatever the severity of the findings. Counted **per mission**.
- A fix round is a developer step answering `@apone` findings or `@ripley` QA findings, plus its paired `@apone` review. A step answering anything else does not increment the counter, but still takes a review immediately behind it under Rule 2.
- Neither trigger outranks the other. Zero CRITICAL findings does not extend the round allowance.
- Every developer fix brief states its round index — `fix round 1 of 2` or `fix round 2 of 2` — and the step it answers — the `@apone` review or the `@ripley` QA step whose findings it addresses. A sub-agent cannot count its own rounds across separate delegations, so a fix brief without the index is malformed. This applies to `@vasquez`'s own rounds exactly as it does to `@hicks`'s. The index goes to the developer only; a review brief carries no round count.
- The escalation brief to `@vasquez` names which trigger fired; the two step numbers behind it — for the severity trigger, the two `@apone` reviews confirming the CRITICAL; for the round trigger, one step number per fix round — the `@apone` review or `@ripley` QA step that round answered, repeated when both rounds answered the same step; and the fix-round index reached. `@vasquez` refuses a call-in missing any of the three, so a brief without them stalls the escalation instead of starting it.
- Bishop never pre-plans that step. It appears during execution or not at all.

### Breaking Them

| What happened | What it costs |
|---------------|---------------|
| `@vasquez` given a step in the initial plan | Plan INVALID. Rewrite before executing. |
| A coding step without `@apone` immediately after | Plan INVALID. Rewrite before executing. |
| Escalating to `@vasquez` before two confirmed junior rounds | Escalation INVALID. Finish the junior rounds. |
| A third junior fix round instead of escalating | Escalation SKIPPED. Mission BLOCKED until `@vasquez` takes it. |
| Code shipped without an `@apone` pass | Quality contract broken. Mission BLOCKED. |
| "It's complex" / "it's architectural" used to justify `@vasquez` up front | Not a valid reason. Rule 1 has no exceptions. |

---

## The Code-Quality Pipeline

Any step where `@hicks` or `@vasquez` creates or changes files outside `.opencode/` is followed **immediately** by `@apone`. Mandatory — a coding step without a review behind it doesn't exist in a valid plan.

1. `@apone` reviews the output. Always. There is no "too trivial to review".
2. **CRITICAL** findings → fix goes to `@hicks` → `@apone` reviews again. That's a new numbered pair of steps.
3. Junior gets **two fix rounds** (each round = one fix step plus one review step). Escalate to `@vasquez` when the same CRITICAL finding is still open after both, or when both rounds are used whatever the severity — whichever comes first. A junior step answering something other than an `@apone` review or a `@ripley` QA finding does not increment the counter, but still takes a review immediately behind it.
4. `@vasquez` remediates → `@apone` reviews again. Senior gets **two fix rounds**.
5. Still failing after two senior rounds → stop and escalate to the operator. Do not keep going.
6. `@lambert` updates docs only where it's warranted: a public API changed, new files appeared, or something README-relevant moved.

**Brief content is Rule 3's job, not this section's.** Every fix brief here — junior or senior — carries the round index and the review step it answers; the escalation brief to `@vasquez` carries the trigger, both `@apone` review step numbers, and the fix-round index reached. See Rule 3 above for the exact wording; this section doesn't restate it, so the two can't drift apart.

The review step is a numbered plan step like any other, and it gets its own state-sync afterwards.

**Sync the findings before the fix round starts.** When a review turns up a CRITICAL and triggers a fix round, the review's *full* findings — the non-blocking WARNINGs and the reasoning behind the decisions, not just the CRITICAL — go into `FLIGHT-RECORDER.md` before the fix begins, not afterwards with the re-review. An interruption between the review and the fix otherwise takes the WARNINGs and the context with it, and the re-review has to rediscover them.

---

## QA Verification — Ripley's Terminal Phase

This section is the canonical statement of how `@ripley` (QA verification) fits a mission. `.opencode/agents/ripley.md` covers her conduct, `.opencode/skills/visual-qa/SKILL.md` the procedure, and `.opencode/commands/qa.md` the standalone command. Where any of them disagrees with this section, this section wins.

### Where She Sits

- Ripley is a **terminal, opt-in phase**, not part of the per-step rotation or the code-quality pipeline. `@apone` follows every coding step automatically; Ripley follows none of them automatically.
- She is never in a plan **by default**. When the operator asks for QA up front, her step may appear in the initial plan, after the final coding step and its `@apone` review; only non-coding steps, such as `@lambert` documentation, may follow it. In the initial plan, a Ripley step anywhere else makes the plan INVALID. The fix, review and re-verify steps her findings lead to are injected during execution, never planned.
- Call her when the work produced a rendered surface — a page, a UI, an interactive feature — and a design reference or written acceptance criteria exists to verify against, or when the operator asks for QA.

### The Pre-Flight Gate (Blocking)

Bishop clears all five before delegating to her. Any one missing is a stop, and Bishop asks the operator, because Ripley cannot — asking the operator is filtered from sub-agents.

Order matters: confirm the environment is non-production (item 4) and read the conf for the target's origin (item 1) before any request goes to the target — the reachability check included. Bishop's shell is outside the guard.

1. **A reachable target URL** — staging, development, localhost, or a preview URL, with an origin the qa-guard plugin (`.opencode/qa-guard.ts`) allows. Read `.opencode/qa.conf` whatever the origin: with no conf, or one that doesn't set `QA_ALLOWED_ORIGINS`, only localhost (`localhost`, `127.0.0.1`, `[::1]`, any port) is allowed; a set `QA_ALLOWED_ORIGINS` replaces that default, a `QA_BLOCKED_ORIGINS` entry always wins, and an entry without a port matches only its scheme's default port (80 for `http`, 443 for `https`). Only the operator writes the conf, or authorises a step that does — Bishop cannot. Then, and only then, confirm it resolves now — a read-only request such as `curl -sI <url>` is enough.
2. **A design reference or written acceptance criteria** — a design file or frame, a screenshot, a specification, or an explicit statement of intent. None supplied is a stop, never an inference.
3. **The target is staged and ready** — built, content in place, forms wired to something safe, authentication arranged if needed. Ready now, not almost.
4. **The environment is named and confirmed non-production**, and the target's origin is not in `QA_BLOCKED_ORIGINS` — that list is where production belongs.
5. **Browser tooling is connected** — at least one Playwright-capable browser tool is available in this session, under a server name Ripley's `tools:` line grants. Bishop confirms it from his own tool list before delegating. With none connected, stop and tell the operator. A screenshot-only review happens only when the operator authorises it for that run, and Ripley's report then says plainly that no browser was driven.

### Before The First Pass

- **Link-check pre-run.** Ripley's browser can read the status of same-origin links and of the assets a page loaded, but not of links to other sites, and she holds no shell. So before her first pass, Bishop runs whatever link checker is installed, read-only, against the target — no cache or report files written, destructive URLs excluded — every pattern on the skip list in `.opencode/skills/visual-qa/technical-integrity.md`, and every `QA_BLOCKED_ORIGINS` entry, because the crawl runs from Bishop's shell, outside the guard. Bishop confirms the checker's cache and output defaults first — its `--help`, for example — and doesn't run it if he can't confirm it writes nothing; its output goes to the terminal, never to a file. Bishop pastes the output into Ripley's brief, the same way `@apone` receives diffs, and does not grade it; Ripley does. No particular checker is required. With none installed, the brief says so and Ripley reports cross-origin links as unchecked.
- **Which browser.** Ripley uses an isolated Playwright automation browser. Operator-logged-in browsers and Chrome DevTools are not used.

### Passes And Rounds

- **First pass** — the initial verification. Its brief carries no round index and is labelled `QA pass — initial`.
- **Re-verify** — after a DEFECT is fixed, or a DEVIATION the operator sent back is fixed, Ripley re-verifies. At most two: `QA re-verify 1 of 2` and `QA re-verify 2 of 2`. Every re-verify brief states its index and names the QA step it follows up. Ripley is stateless and cannot count her own passes, so a re-verify brief without its index is malformed and she refuses it.
- **At most three Ripley passes per mission.** A DEFECT, or a DEVIATION the operator sent back, still open after `QA re-verify 2 of 2` ends the QA phase and goes to the operator.

### Fixing What She Finds

- A developer step answering Ripley's findings is a fix round under Rule 3, which says how it counts and what its brief carries.
- Whoever holds the code fixes it — `@hicks`, or `@vasquez` once escalation has happened. If Rule 3's round trigger fires during QA fixes, escalate before the next fix.
- Every QA fix step is followed immediately by `@apone` (Rule 2). Only then does Ripley re-verify.
- Fix, review and re-verify steps are Bishop-injected steps: each gets its PROGRESS.md row before its brief goes out, under the injected-step rule.

### Her Verdicts

- Ripley grades in her own vocabulary — **DEFECT**, **DEVIATION**, **OBSERVATION**, **PASS** — and never uses CRITICAL, which belongs to `@apone` and drives the severity trigger. Her findings never count toward the severity trigger.
- **DEFECT** — the intent is not met. An open DEFECT blocks the mission from closing as `done`: it is fixed and re-verified, or the operator decides — accepting the risk, recorded in the `QA Verdict` section of `DEBRIEF.md`, or closing the mission `failed`.
- **DEVIATION** — it works, but does not match the design or stated intent. The operator accepts it or sends it back for a fix; Bishop never decides on the operator's behalf. Accepted deviations are recorded in the `QA Verdict` section of `DEBRIEF.md`.
- **OBSERVATION** — non-blocking; recorded.
- Items Ripley reports as unverified, or as needing human review, are listed and recorded in the `QA Verdict` section of `DEBRIEF.md`. They do not block.
- Severity is hers alone. A QA brief may say what to look at, never what will be found — no proposed severity, no count of passes closed without a DEFECT, no "cosmetic" or "minor" before she has graded it. Bishop never overrides a grade.

### Evidence

Ripley keeps screenshots, console and network captures, and working notes under `.opencode/memory/workspace/qa/<run-id>/`. It is scratch like the rest of the workspace, and it is archived with every other file there at the next mission init.

### Standalone `/qa`

- Outside a mission, `/qa` only reports. Anything that needs fixing becomes a `/mission`. Ripley runs as a subagent there too; the guard depends on it.
- While a mission is `in-progress`, QA work is an injected step in that mission — its PROGRESS.md row goes in before the work is delegated, as for any injected step.

### What Is Not Enforced

The qa-guard plugin (`.opencode/qa-guard.ts`) is the mechanical backstop, and it has gaps. When the running agent's identity is not visible to the plugin, Write/Edit confinement is doctrine-only and the guard checks browser-tool calls only. Unrecognised path-field names and nested objects pass through. Clicks, form submits, in-page fetch/XHR and `window.open` are never seen by the guard. These gaps are covered by `.opencode/agents/ripley.md`'s conduct rules, not by mechanism.

---

## Findings And Learning

### The Chain

Every finding write follows this path. It's built so the pass can't be quietly skipped — collection forces it, rather than memory being asked to.

1. **Sub-agents** end **every** step-completion report with an `IMPROVEMENT-NOTE:` line, sitting immediately above the `STEP N COMPLETE` line. The value is `none` when there was nothing — valid and expected — or one concrete, actionable observation. A report missing the line is malformed, and Bishop asks for it before syncing.
2. **Bishop delegates** each non-`none` note to `@lambert` as part of the same state-sync it hands out for that step — one line per finding: step, agent, note. Bishop writes no files, so the append is never by Bishop's own hand and never a separate delegation. `none` values aren't recorded.
3. **Bishop** at completion reads that scratch list, adds its own Bishop-level observations, and applies the Quality Gate in `.opencode/skills/self-improvement/SKILL.md` to decide what qualifies.
4. **Bishop delegates** whatever qualifies to `@lambert`, naming the file targets and the entry content, per `.opencode/templates/findings/FINDINGS-TEMPLATE.md`.
5. **`@lambert`** appends. It executes; it doesn't decide what's worth recording.

> **The pass always runs; the writes are conditional.** An empty scratch list — every step reported `none` — means the pass finishes with no file writes, and that's a complete outcome. What's not allowed is skipping the collection or the pass. `findings-scratch.md` is scratch: it's archived at the next new-mission init like anything else in `workspace/`.

**A process observation that would change the next brief goes into that brief now.** It doesn't wait for the pass at the end. Ask review and verification steps for process observations mid-mission, not only at completion; where one is actionable — a bundled acceptance criterion that should have been two questions, a question phrased so it can't fail — rewrite the next brief and say in it that you did. It still gets appended to the scratch file; the two aren't alternatives. The completion pass can't change an outcome. The next brief can.

### Applying Approved Findings

**Approved findings too.** `@hicks`, `@vasquez`, and `@apone` read `.opencode/memory/findings/FINDINGS.md` during their own work — not only at completion — and apply any entry a human has moved to `approved` that bears on what's in front of them. Like `DIRECTIVES.md`, it is read-only to them here too: no agent sets or changes a `Status`, an `Approver`, or a `Date approved`.

### Agent Notes (`findings/service-records/<agent-name>.md`)

- Written only when something noteworthy happened — good or bad.
- Nothing notable means nothing written. No "no issues" entries.
- Either self-reported (the agent noting its own behaviour) or bishop-observed (Bishop noting it). Both valid — set `Source` accordingly.
- Written at completion, during the learning pass delegation.

### FINDINGS.md

- Written at **completion only**.
- The findings ledger: specific, observed findings, one entry per observation. May cite code, paths, and symbols.
- Concrete and actionable — a change to a prompt, a skill, a tool, or a candidate directive. Nothing vague.
- Has to clear the Quality Gate in `.opencode/skills/self-improvement/SKILL.md`.
- A single occurrence is enough. You don't need to see something twice before recording it.
- Nothing to report means no write. No empty entries, no placeholders.
- `Status` belongs to the human operator (`proposed` → `approved` → `applied`, with `rejected`, `retired`, and `superseded` as terminal branches). No agent sets it, changes it, or touches `Approver`/`Date approved`.

### PATTERNS.md

- Written at **completion only**.
- Reusable solutions, architecture decisions, and technical approaches. Advisory and non-binding — `DIRECTIVES.md` wins on any conflict.
- Has to clear the Quality Gate.
- Nothing to report means no write.

### When The Same Finding Keeps Coming Back

A finding logged three or more times is telling you something the ledger can't fix. It means an agent or skill definition has a hole in it, not that a directive is missing. Fix the definition — don't log the finding a fourth time.

That fix is a **proposal, not an edit**. Agent and skill definitions are human-ratified, exactly like `DIRECTIVES.md`. An agent that spots a definition-level hole records the proposal and puts it in front of the operator; it does not amend the definition mid-mission.

### The Rule

> The learning pass runs at the end of every mission, without exception. Files get written only where findings are concrete, actionable, and clear the Quality Gate. Empty, vague, or placeholder entries are forbidden.

---

## The Directives Contract

`.opencode/memory/reference/DIRECTIVES.md` holds binding directives that a human ratified — generalised practices and methodologies, not only coding rules. Every entry exists to prevent a **class** of problem, never the single instance that prompted it. It sits deliberately outside the findings loop:

- **Read before acting.** `@hicks`, `@vasquez`, and `@apone` read every entry whose **Applies when** trigger their change satisfies — before writing or reviewing — and comply.
- **Binding beats advisory.** On any conflict, `DIRECTIVES.md` (ratified) overrides `PATTERNS.md` (observed).
- **Agents never write to it.** A discovered directive is proposed through `FINDINGS.md` as `proposed`; a human ratifies it across. That is the only path, under any circumstances.
- **Reviewer enforces it.** `@apone` tests the change against the `Reviewer check` of every triggered `active` entry. A violation is CRITICAL.
- **No match gets reported too.** When a change triggers **no** `active` entry, `@apone` says so explicitly — describing the change and stating that nothing covered it. That's a coverage gap, not a violation: never CRITICAL, never blocking. It exists so "passed because nothing applied" reads differently from "passed because it complied". An unmatched change is a candidate for a new directive through the proposal path, and silence is how that candidate disappears into an apparently clean review.
- **Not a finding.** Ratified directives aren't logged as rules in `FINDINGS.md` or `PATTERNS.md`. Only the human-ratification path adds to `DIRECTIVES.md`.

---

## Starting A Mission — Checklist

Bishop derives the mission ID first (see Mission IDs above), then confirms all of this, via delegation to @lambert:

1. [ ] `.opencode/memory/workspace/` cleared in the archive sense — `.gitkeep` and `README.md` kept, every other `.md` moved to `archive-mission-[id]/`, `findings-scratch.md` recreated with a fresh header — and proven by a returned `ls -la` of the directory. A stated claim without the listing doesn't satisfy this item.
2. [ ] `.opencode/memory/missions/mission-[id]/BRIEF.md` built from `.opencode/templates/mission/MISSION-TEMPLATE.md`, exactly. Every path written into `Key Files` confirmed to exist as it's written; a path that doesn't exist yet is marked `— to be created at step N`, never left bare. A wrong path in canonical mission state is invisible guidance — later agents assume the documented structure is right and nobody questions it.
3. [ ] `.opencode/memory/missions/mission-[id]/PROGRESS.md` built from the same template, exactly, with the step table filled in for every planned step
4. [ ] `state/CURRENT-MISSION.md` initialized — new mission id, status `in-progress`, owner, next action
5. [ ] `state/FLIGHT-RECORDER.md` present and ready for the first append

All five confirmed before the first numbered step runs.

---

## Closing A Mission — Checklist

Once every step is done, in this exact order:

1. [ ] Final state-sync (last step marked done, FLIGHT-RECORDER row appended with event=step-sync)
2. [ ] Closing summary written for the operator
3. [ ] **Tracker-and-reality check (BLOCKING):** diff every canonical tracker the mission touched — a project `progress.md`, a README status table, anything that claims what's done — against what's actually on disk. Drift either way is a blocking discovery: code present with no completed step, or a tracker claiming completion with the code missing. Sync the tracker before closing, or record the drift explicitly in `DEBRIEF.md` using the three kinds of not done from Terms above. Remediation you carry out here is a step: give it a PROGRESS.md row and a sync before continuing the close, then note the drift and its fix in `DEBRIEF.md`.
   - **QA verdicts (BLOCKING, when Ripley ran):** no DEFECT is open unless the operator has decided on it, and every DEVIATION carries the operator's accept-or-fix decision. Each decision, every accepted DEFECT risk, and every item Ripley reported as unverified or needing human review is recorded in the `QA Verdict` section of `DEBRIEF.md`.
4. [ ] **Learning pass run (BLOCKING — you cannot skip it):**
   - 4a. [ ] Bishop reads `.opencode/memory/workspace/findings-scratch.md` — the notes collected as the steps ran. That list *is* the input; the pass consolidates it rather than recalling it.
   - 4b. [ ] Bishop reviews its own observations — Bishop-level patterns, agent behaviour, delegation and skill gaps
   - 4c. [ ] Anything concrete? Delegate the writes to `@lambert` with named file targets and entry content, per `.opencode/templates/findings/FINDINGS-TEMPLATE.md`, all applicable files in one delegation
   - 4d. [ ] `@lambert` appends to `FINDINGS.md`, `PATTERNS.md`, and/or `service-records/[name].md` as applicable. Every `FINDINGS.md` entry carries `**Mission**: mission-[id]` — in central mode that line is what links the finding to its mission in bishop-memory
   - Nothing found? The pass is complete. No delegation, no writes.
5. [ ] `missions/mission-[id]/DEBRIEF.md` written by `@lambert` from `.opencode/templates/mission/DEBRIEF-TEMPLATE.md`
   - Mandatory sections: wrong assumptions, and per-agent mistakes with corrective actions
   - Written once at completion — not maintained as a rolling log
   - Applies to active and newly finished missions only. No retroactive backfill unless asked.
6. [ ] `state/CURRENT-MISSION.md` set to `complete`, Next Action set to `none` (the completion gate checks DEBRIEF.md exists)
7. [ ] FLIGHT-RECORDER row appended with event=complete (schema in STATE-FILE-TEMPLATE.md)
8. [ ] Row appended to `state/MISSION-ARCHIVE.md`
   - Append-only, columns exactly `Mission ID | Completed | Outcome | Summary`
9. [ ] Every logical step confirmed to have sync evidence before the mission closes
10. [ ] Reconcile bishop-memory with the Markdown (central mode only)
    - Skip when `.opencode/bishop-memory.conf` is absent or `BISHOP_MEMORY_MODE` is not `central`
    - Run `.opencode/lib/reconcile-bishop-memory.sh` from the project root. It reads `BISHOP_MEMORY_HOME`, `BISHOP_MEMORY_URL` and `BISHOP_HARNESS` from the conf and always passes `--harness`, so every finding, pattern and service record is attributed to this harness
    - Runs after step 8 so the mission's outcome is present in MISSION-ARCHIVE.md
    - Idempotent and safe to re-run; a non-zero exit means the derived copy is stale, not that the close failed

### The Closing Gate

Bishop does not mark `CURRENT-MISSION.md` complete or append to `MISSION-ARCHIVE.md` until the tracker-and-reality check (3), the learning pass (4), and `DEBRIEF.md` (5) have all run. Skip or defer any of the three and the mission stays `in-progress` and cannot close. This is as serious as skipping a per-step sync.

### The Plugin Gate

`.opencode/mission-guard.ts`, registered through `opencode.json`, enforces two advisory/hard gates on file writes:

- **Completion gate (hard block)** — refuses to let `CURRENT-MISSION.md` go to `complete` unless the mission's `DEBRIEF.md` exists **and** carries both mandatory sections, `Wrong Assumptions` and `Sub-Agent Mistakes and Corrections`, each with at least three pipe-prefixed lines (header, separator, and at least one data row). A heading alone is not enough.
- **State-continuity gate (advisory warning)** — checks cross-mission staleness, within-mission lag, and structural validation of the newest flight-recorder row (pipes, six cells, timestamp format, ordering). It warns but does not block, so the manual read-back by @lambert remains the authoritative check.

Both gates are reversible. They back up the written rules; they don't replace them. They also fail open where the host environment lacks required capabilities, by design: a jammed loop is worse than a missed advisory check.

### What Is Not Enforced

Almost everything in this file is prose instruction to a model. Two things have mechanical backing, and neither is absolute — the bullets below say where each stops. `.opencode/mission-guard.ts` refuses a write that sets `CURRENT-MISSION.md` to `complete` unless a `DEBRIEF.md` exists carrying both mandatory headings. Everything else is compliance rather than mechanism. Being specific about the gaps matters more than the reassurance of not naming them:

- **The plugin matches file writes only.** A shell mutation — `sed -i`, a redirect, a heredoc, `tee` — may be invisible to the plugin. Any agent holding Bash can write a state file with no gate consulted and no warning raised.
- **No path in this repository is protected from an agent.** Path-based rules over agents, skills, and `DIRECTIVES.md` were deliberately avoided: locking the harness's own files blocked their own correction. Human ratification of agent and skill definitions is doctrine, not mechanism.
- **Fail-open means not-enforced on a host missing a capability.** Without required tooling the completion gate stands aside entirely.
- **The mandatory-section check counts pipe-prefixed lines, not filled-in content.** The gate requires at least three lines starting with `|` under each heading — header, separator, one row, by shape alone. `DEBRIEF-TEMPLATE.md`'s own unfilled placeholder rows already clear that count, so a DEBRIEF.md submitted as the bare template — headings present, every field still reading `[assumption]` or `[what went wrong]` — satisfies the gate exactly as a properly filled-in one would.
- **`MISSION-ARCHIVE.md` has no gate.** Nothing prevents an outcome row being appended out of order, or at all.
- **`CURRENT-MISSION.md`'s `Last Updated` is checked by nothing.** Only `FLIGHT-RECORDER.md` rows have their ordering verified, and only the newest one.
- **The delegation contract is not mechanically enforced at any point.** Rule 1, Rule 2, the fix-round limits, the escalation triggers, the per-step sync, the tracker check and the learning pass are all compliance, not mechanism.

Treat every other "blocking gate" in this document as a rule an agent is asked to follow, and write briefs accordingly.

---

## What A Plan Looks Like

```
Plan for mission-20260711-01:
1. @hicks — Create authentication module
   → [state-sync delegation to @lambert]
2. @apone — Review authentication module
   → [state-sync delegation to @lambert]
3. @hicks — Fix any CRITICAL issues from review
   → [state-sync delegation to @lambert]
4. @lambert — Update README with auth docs
   → [state-sync delegation to @lambert]
Close: summary → tracker check → learning pass (BLOCKING) → DEBRIEF (BLOCKING) → CURRENT-MISSION complete → MISSION-ARCHIVE
```

Every `→ [state-sync delegation]` is required at runtime and cannot be put off.

---

## The Whole Thing, End To End

```
OPERATOR REQUEST
    │
    ▼
┌─────────────────────────────────────────┐
│ PLANNING                                │
│ Goal → Criteria → Risks → Plan          │
│ ⚠️ Every code step → @hicks             │
│ ⚠️ Every code step → @apone             │
│ ⚠️ @vasquez NEVER in the plan           │
└─────────────────────┬───────────────────┘
                      │ plan settled
                      ▼
┌─────────────────────────────────────────┐
│ INITIALIZATION                          │
│ Mission ID → archive → BRIEF → PROGRESS │
│ CURRENT-MISSION → FLIGHT-RECORDER       │
│ ⚠️ All 5 confirmed before step 1        │
└─────────────────────┬───────────────────┘
                      │ confirmed
                      ▼
┌─────────────────────────────────────────┐
│ EXECUTION LOOP (every step)             │
│ A.Hand out → B.Read → C.Sync →          │
│ D.Confirm → E.Continue                  │
│ ⚠️ The sync blocks the next step        │
│ ⚠️ Same turn as the step report         │
│                                         │
│ Code step? → CODE-QUALITY PIPELINE      │
└─────────────────────┬───────────────────┘
                      │ all steps done
                      ▼
┌─────────────────────────────────────────┐
│ CLOSING GATE                            │
│ A.Summary → B.Tracker check →           │
│ C.Learning pass → D.DEBRIEF →           │
│ E.Mark complete →                       │
│ F.FLIGHT-RECORDER complete row →        │
│ G.Append MISSION-ARCHIVE                │
│ ⚠️ B, C and D all block the close       │
└─────────────────────────────────────────┘
```

---

## Everything That Blocks

| Checkpoint | Kind | What it stops |
|------------|------|---------------|
| @hicks on every initial code step | Hard rule | Plan INVALID otherwise |
| @apone directly after every code step | Hard rule | Plan INVALID otherwise |
| @vasquez absent from the initial plan | Hard rule | Plan INVALID otherwise |
| Mission ID derived locally from folders *and* logs, or allocated by bishop-memory in central mode | Hard rule | A reused ID makes the audit trail ambiguous |
| All 5 initialization items confirmed | Blocking gate | Step 1 can't start |
| State-sync after each step, in the same turn | Blocking gate | Next step can't start |
| Sync validation (FLIGHT-RECORDER + CURRENT-MISSION + PROGRESS, plus findings-scratch.md when the note isn't `none`) | Blocking gate | Execution can't continue |
| FLIGHT-RECORDER row re-read and verified after append | Blocking gate | Sync can't be reported complete |
| Two junior fix rounds maximum, per mission | Escalation rule | Must go to @vasquez |
| Two senior fix rounds maximum | Escalation rule | Must go to the operator |
| Tracker-and-reality check at completion | Blocking gate | Mission can't close |
| Learning pass at completion | Blocking gate | Mission can't close |
| DEBRIEF written at completion | Blocking gate | Mission can't close |
| CURRENT-MISSION marked complete before MISSION-ARCHIVE | Sequencing | MISSION-ARCHIVE can't be appended |
| FLIGHT-RECORDER `complete` row appended before MISSION-ARCHIVE | Sequencing | Journal and MISSION-ARCHIVE disagree about whether the mission ever closed |

---

**Of everything in that table, two rows have some mechanical backing, and the two differ in kind.** `DEBRIEF written at completion` is enforced by `.opencode/mission-guard.ts`, which refuses the transition to `complete` without it — that row blocks. `FLIGHT-RECORDER row re-read and verified after append` is backed too, partially: `.opencode/mission-guard.ts` runs the same four structural checks — leading and trailing pipes, six cells, a valid timestamp, and forward ordering — automatically, on every relevant write, but only as an advisory warning. It never denies the write, so the row's blocking force still rests on @lambert's manual read-back, not on the plugin. Every other row is doctrine — a rule an agent is asked to follow, with nothing checking that it did. See What Is Not Enforced above.

## Templates

| For | File |
|-----|------|
| State file schemas | `.opencode/templates/state/STATE-FILE-TEMPLATE.md` |
| Mission files (BRIEF.md, PROGRESS.md) | `.opencode/templates/mission/MISSION-TEMPLATE.md` |
| Completion report (DEBRIEF.md) | `.opencode/templates/mission/DEBRIEF-TEMPLATE.md` |
| Finding entries | `.opencode/templates/findings/FINDINGS-TEMPLATE.md` |
| Directive entries (format scaffold) | `.opencode/templates/reference/DIRECTIVES-TEMPLATE.md` |

---

## See also

- `.opencode/skills/junior-coding/SKILL.md` — @hicks workflow and escalation triggers.
- `.opencode/skills/code-review/SKILL.md` — @apone review format and rules.
- `.opencode/skills/senior-architecture/SKILL.md` — @vasquez escalation path.
- `.opencode/skills/self-improvement/SKILL.md` — findings quality gate and learning loop.
- `.opencode/skills/documentation/SKILL.md` — state-file writing style.
- `AGENTS.md` — crew roles, bishop-memory doctrine, and MCP tool surface.
