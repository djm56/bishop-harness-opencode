# Skill: code-review

# Code Review

This skill defines how `apone` performs code reviews in the Bishop harness. Reviews are mandatory after every coding step.

## Purpose

Code review is the primary quality gate. `apone` reads the diff produced by a coding step and issues one of three verdicts:

- **APPROVED** — the change is correct, safe, and consistent with doctrine.
- **CHANGES_REQUESTED** — the change has issues that must be fixed before the mission continues.
- **CRITICAL** — the change introduces a security, data-loss, or architectural risk and must be escalated to `bishop` immediately.

## When to review

Review immediately after every coding step, before the next step begins. Do not batch reviews across steps.

## Review scope

Read the diff relative to the last approved state. Consider:

1. Correctness — does the code do what the step claimed?
2. Security — are inputs validated, outputs escaped, secrets handled?
3. Style — does it match project conventions?
4. Doctrine — does it follow the skills, `AGENTS.md`, and `DIRECTIVES.md`?
5. Completeness — are docblocks, tests, and runbooks updated as needed?

## Output format

`apone` must produce a structured review with these sections:

```text
## VERDICT

APPROVED | CHANGES_REQUESTED | CRITICAL

## CRITICAL (if any)

- Issue and why it is critical.
- Required fix.

## WARNINGS

- Issues that should be fixed but are not blockers.

## SUGGESTIONS

- Optional improvements that do not block approval.

## NOTES

- Anything else the next agent needs to know.
```

## Review rules

- Be specific. Quote line numbers or function names.
- Distinguish blockers from polish.
- Do not rewrite the code in the review; ask `hicks` to fix it.
- If two review rounds fail to clear a blocking issue, escalate to `bishop` for `vasquez`.
- If the change is outside the step's scope, request rollback or clarification.

## Security checklist

For every change that touches:

- User input
- File paths
- Database queries
- Network calls
- Credentials or tokens

verify:

- [ ] Inputs are validated or escaped.
- [ ] Outputs are encoded for the target context.
- [ ] No secrets are logged or committed.
- [ ] File operations use canonical paths and check boundaries.
- [ ] SQL / shell construction uses parameterisation, not concatenation.

## Performance checklist

For every change that touches:

- Loops
- Database queries
- Network calls
- Large data structures

verify:

- [ ] Big-O complexity is appropriate.
- [ ] Queries are indexed or bounded.
- [ ] Network calls are retried idempotently.
- [ ] Memory usage is bounded.

## Documentation completeness

- [ ] New public functions/methods have docblocks.
- [ ] Changed APIs have updated docblocks.
- [ ] README / runbook changes accompany user-visible changes.

## Handling disagreements

If `hicks` disagrees with a review finding:

1. `hicks` explains the reasoning in the step thread.
2. `apone` either withdraws the finding or confirms it.
3. If unresolved after one round, `bishop` decides.

## Review is not optional

A step is not complete until `apone` approves it. If `apone` is unavailable, `bishop` does not advance the mission.

## See also

- `.opencode/skills/junior-coding/SKILL.md` — fix rounds and escalation.
- `.opencode/skills/code-documentation/SKILL.md` — documentation standards.
- `AGENTS.md` — crew roles and the task tool.
