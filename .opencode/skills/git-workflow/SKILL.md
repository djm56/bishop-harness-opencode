# Skill: git-workflow

# Git Workflow

This skill defines the git conventions used by the Bishop harness. All crew members follow it; `bishop` enforces it during planning.

## Purpose

A predictable git workflow keeps missions reviewable, reversible, and independent. The harness is deliberately conservative: feature branches, small commits, and explicit merge handling.

## Branch model

- `main` is the production branch.
- Missions create a task branch from `main`.
- No direct pushes to `main` except automated doc-only updates approved by `bishop`.

## Task branch naming

Format:

```text
mission/<mission-id>/<short-slug>
```

Examples:

```text
mission/mission-20260905-01/fix-importer-escaping
mission/mission-20260905-02/docs-provider-setup
```

If the mission is not yet allocated, use a descriptive slug and rename when the mission ID is known.

## Commit conventions

Use imperative mood, lowercase, concise:

```text
Fix importer path escaping for nested archives
Add provider configuration section to INSTALL
Update mission-lifecycle skill with task tool references
```

A commit should:

- Do one thing.
- Be reviewable in isolation.
- Reference the mission ID in the body when it closes or advances a mission.

## Commit message body

Include:

- Why the change was made.
- What trade-offs were considered.
- A reference to the mission and step.

Example:

```text
Fix importer path escaping for nested archives

The previous split on `/` failed when archive names contained slashes.
Switch to the archive's internal basename and validate against an allow-list.

Mission: mission-20260905-01
Step: 12
```

## Pull / merge requests

- One PR per mission or per discrete deliverable.
- PR title matches the branch slug.
- PR body contains a short summary, testing notes, and a link to the mission folder.
- `apone` must approve before merge.
- Merge with a merge commit unless the project mandates rebase.

## Merge conflict resolution

1. Pull the latest target branch.
2. Rebase the task branch or merge the target branch in — follow project convention.
3. Resolve conflicts file by file.
4. Re-run tests / linters.
5. `apone` re-reviews if the diff changed materially.

## Hotfix branches

For production fixes outside a planned mission:

```text
hotfix/<short-slug>
```

Open a PR to `main` with expedited review. Log a retrospective mission after merge.

## Staging branches

If the project uses `staging`:

- Merge mission branches to `staging` first.
- Promote `staging` to `main` via a separate PR.
- Resolve staging-specific conflicts in a branch cut from `staging`, not `main`.

## Cleanup

- Delete merged task branches.
- Keep the local clone tidy; stale branches confuse `graphify` and future missions.

## Tagging releases

Use semantic versioning:

```text
git tag -a v1.2.3 -m "Release v1.2.3 — mission-20260905-01"
```

## State-sync notes

When a step updates state files, the commit should be atomic with the code change when possible. If state files live outside the product repo (the harness default), append them before the code commit and reference the step in `FLIGHT-RECORDER.md`.

## See also

- `.opencode/skills/mission-lifecycle/SKILL.md` — mission state and state-sync rules.
- `.opencode/skills/junior-coding/SKILL.md` — commit-ready self-checks.
- `AGENTS.md` — crew roles and task tool usage.
