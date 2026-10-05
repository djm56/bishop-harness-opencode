# Skill: code-documentation

# Code Documentation Standards

This skill covers how to write docblocks and inline comments in Bishop harness code. It applies to both junior and senior developers.

## Purpose

Good documentation lowers the cost of every subsequent mission. The crew reads docs before writing code, and reviewers read docs before reviewing code. Bad documentation — missing, misleading, or stale — is a defect like any other.

## Scope

Applies to:

- PHP, JavaScript/TypeScript, Python, and shell code produced by the crew.
- README files, ADRs, and runbooks owned by `lambert`.

Does **not** apply to:

- Auto-generated files.
- Third-party code.
- One-off scratch notes in `memory/workspace/`.

## Docblock style

### Functions and methods

Use the language's native docblock style.

**PHP:**

```php
/**
 * Summarise what the function does in one sentence.
 *
 * @param string $name  Parameter description.
 * @param int    $count Parameter description.
 * @return bool Description of the return value.
 * @throws InvalidArgumentException When and why this is thrown.
 */
function example(string $name, int $count): bool {
```

**JavaScript / TypeScript:**

```js
/**
 * Summarise what the function does in one sentence.
 *
 * @param {string} name  - Parameter description.
 * @param {number} count - Parameter description.
 * @returns {boolean} Description of the return value.
 * @throws {TypeError} When and why this is thrown.
 */
function example(name, count) {
```

**Python:**

```python
def example(name: str, count: int) -> bool:
    """Summarise what the function does in one sentence.

    Args:
        name: Parameter description.
        count: Parameter description.

    Returns:
        Description of the return value.

    Raises:
        ValueError: When and why this is raised.
    """
```

### Classes

Document the class purpose and any invariants. Document every public method. Private methods only need documentation when the logic is non-obvious.

### Files

Add a short file-level docblock when:

- The file is an entry point.
- The file contains more than one conceptual concern.
- The file is referenced from `AGENTS.md` or a skill.

## Inline comments

Use inline comments for:

- Non-obvious business rules.
- Workarounds with a ticket or decision link.
- Complex conditionals or indexing.
- Anything that surprised you while writing it.

Do **not** comment the obvious:

```php
// Bad: increments count by one
$count++;
```

## Parameter and return documentation

- Every parameter gets a description.
- Flag the units of numeric values (`ms`, `bytes`, `UTC timestamp`).
- Document nullable / optional values.
- Return values must be described, including failure sentinel values (`false`, `null`, `0`).

## Exception documentation

- Document every exception the function can throw.
- Include the condition that causes it.
- Do not document exceptions thrown by dependencies unless they leak through the public API.

## Language-specific notes

### PHP

- Follow PHPDoc conventions.
- Prefer `int` over `integer`, `bool` over `boolean` in type hints.
- Use `@since` tags for plugin APIs.

### JavaScript / TypeScript

- Use JSDoc for plain JS. TypeScript types in signatures reduce the need for `@param` types, but descriptions are still required.
- Prefer `//` for inline comments; reserve `/* */` for docblocks.

### Python

- Use Google-style docstrings.
- Include type hints in signatures; repeat types in docstrings only when it adds clarity.

### Shell

- Start every non-trivial script with a header comment: purpose, usage, exit codes.
- Document functions with a short comment above the definition.
- Explain non-obvious `sed` / `awk` / `grep` invocations.

## Documentation-driven changes

When a change alters a public API, update the docblock first. The reviewer checks that docs and code agree. If they disagree, the code is wrong until the docs are updated.

## Review checklist

`apone` should verify:

- [ ] Every public function/method has a docblock.
- [ ] Parameters and return values are documented.
- [ ] Exceptions are documented where applicable.
- [ ] Inline comments explain non-obvious logic.
- [ ] No comments restate the code literally.
- [ ] README / runbook changes keep pace with code changes.

## See also

- `.opencode/skills/junior-coding/SKILL.md` — implementation workflow.
- `.opencode/skills/senior-architecture/SKILL.md` — architecture decision records.
- `AGENTS.md` — crew roles and delegation.
