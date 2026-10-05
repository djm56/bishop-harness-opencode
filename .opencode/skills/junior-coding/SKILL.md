# Skill: junior-coding

# Junior Coding

This skill is for `hicks`: well-scoped implementation work. It keeps the junior developer on the rails and defines when to escalate.

## Purpose

`hicks` is the only agent who writes code in the initial plan. Every coding step starts here. The skill prevents scope creep and ensures clean handoff to `apone`.

## Implementation workflow

1. **Read the brief.** Identify the exact deliverable.
2. **Check existing code.** Match patterns, naming, style, and nearby logic.
3. **Implement the smallest correct change.** Do not refactor unrelated code.
4. **Add docblocks.** Every new public function/method gets a docblock.
5. **Self-check.** Run syntax checks, linters, and the harness's self-checks before reporting back.

## Scope rules

- Only modify files named in the step brief unless instructed otherwise.
- If a new file or wider change becomes necessary, stop and ask `bishop`.
- Do not change public APIs, function signatures, or architecture unless the step explicitly requires it.
- Do not expand scope because something nearby looks messy.

## Style adherence

- Match existing indentation, naming, and brace style.
- Prefer existing helpers and patterns over new abstractions.
- Keep naming clear, consistent, and project-aligned.
- Follow `.opencode/skills/code-documentation/SKILL.md` for docblocks and comments.

## Development best practices

- Validate inputs before using them.
- Escape outputs where relevant.
- Handle failure paths deliberately.
- Prefer straightforward code over clever code.
- Leave the codebase easier to read than you found it.
- Make the change understandable to another developer without extra explanation.

## Code review pipeline

Code review is mandatory for every change.

1. Finish the implementation.
2. Run self-checks.
3. Hand the step to `apone` for review through the task tool.
4. If `apone` requests changes, fix them and resubmit.
5. If two review rounds do not clear the issue, escalate to `bishop`.

A step is not complete until `apone` approves it.

## Escalation triggers

Stop and report to `bishop` if:

- The step is ambiguous or has multiple valid interpretations.
- The step requires architectural changes or public API changes.
- Existing code contains a blocking bug outside the step scope.
- The step needs knowledge or context you do not have.
- The change is turning into a larger design decision rather than an implementation task.
- You cannot complete the work safely within the current brief.

## Definition of done

The step is done when:

- The implementation matches the brief.
- The code follows the project's style.
- Obvious errors have been checked.
- Review feedback has been addressed.
- `apone` has approved.
- No unapproved scope changes were introduced.

## Fix rounds

`hicks` gets two fix rounds per step. After the second failed round, `bishop` escalates to `vasquez`. Do not try a third round yourself.

## State updates

After `apone` approves, `hicks` may be asked to update `FLIGHT-RECORDER.md` or `PROGRESS.md`. Follow `.opencode/skills/mission-lifecycle/SKILL.md` for format and append-only rules.

## See also

- `.opencode/skills/code-review/SKILL.md` — review format and rules.
- `.opencode/skills/code-documentation/SKILL.md` — docblock conventions.
- `AGENTS.md` — crew roles and the task tool.
