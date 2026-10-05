# Directives — The Format Scaffold

> **What this file is.** The **only** home for the authoring steps, the Entry Template, and the length budget used by `.opencode/memory/reference/DIRECTIVES.md`. That file is the authoritative source of binding, human-ratified directives for this harness — generalised practices and methodologies, not only coding rules. This file describes the *form* of an entry. It holds no binding entries of its own.
>
> **Who writes it.** Humans. Only humans. Agents do not edit `DIRECTIVES.md`. An agent that spots a candidate directive PROPOSES it through `.opencode/memory/findings/FINDINGS.md` as `proposed`, and a human ratifies it across.
>
> **How it relates to the rest.** `FINDINGS.md` holds specific observed findings and may cite code. `PATTERNS.md` holds what agents have observed — advisory, and it loses to `DIRECTIVES.md` on any conflict. `DIRECTIVES.md` holds what a human has ratified — binding.
>
> **The binding clauses live in `DIRECTIVES.md`, not here.** Its `## How Entries Bind` section states the three clauses every entry inherits: scope of binding, rule over example, and intent tests rather than site lists. Read them before drafting — they're the reason an entry never carries its own exemption list, and they are deliberately **not** repeated in this file.

## Adding An Entry

1. Take the next free ID (`DIR-NNN`, zero-padded, never reused). IDs are permanent.
2. Copy the Entry Template below and fill every mandatory field. `Example` is optional — leave it out rather than writing `n/a`.
3. Add a row to the Directive Index in `DIRECTIVES.md`, in the header form shown below.
4. Write `Applies when` as an observable property of the change — *"A change that \<verb\>s \<object\>"*. Never a path or a glob, and never a state of the world the reviewer has to infer.
5. Set `Status: active`. Retiring a rule means `Status: deprecated`, its row moved to the `## Retired Entries` table naming the successor, and the entry left in place — IDs are permanent and entries are never deleted. The literal words `active` and `deprecated` are read by the reviewer and developer instructions; don't reword them.
6. Keep the entry inside the length budget below. An entry that won't fit isn't one directive.
7. Write the `Rule` as a position or an intent, never as a list of the sites it spares. Any qualifier that narrows the rule gets repeated in every field that states the rule.

## Entry Template

```
### DIR-NNN — <short title, ≤60 chars>
- **Applies when:** <observable trigger, phrased "A change that <verb>s <object>". Readable off the diff or the brief, never a state of the world the reviewer must infer.>
- **Status:** active | deprecated
- **Rule:** <one to four sentences. MUST / MUST NOT. A position or an intent, never the sites it spares. No file:line, no project or product names, no enumerated site lists.>
- **Rationale:** <one sentence: the failure mode this prevents. Not the ratification argument — that stays in FINDINGS.md.>
- **Reviewer check:** <one or two questions with determinate yes/no answers against the change. No "do not flag" lists — the three binding clauses cover those.>
- **Example:** <OPTIONAL. One line, synthetic, prefixed "Illustrative —". Never a live file, never file:line.>
- **Added:** <YYYY-MM-DD> · **Supersedes:** <retired DIR ids, if any> · **Source:** <mission id / person> · **Evidence:** <[YYYY-MM-DD] — target, ≤80 chars, resolvable by one grep on that date in FINDINGS.md>
```

**Six mandatory fields, plus an optional `Example`.** Four of the names — `Status`, `Rule`, `Rationale`, `Reviewer check` — are referenced by name in binding agent and skill files. Rename any of them and the mandatory directives check silently stops working, so they're fixed.

**The `Evidence:` form.** `[YYYY-MM-DD] — <target>`, 80 characters or fewer, resolvable by one grep on that date in `FINDINGS.md`. Don't quote a whole heading — it rots the moment the heading changes. Where a date-and-target pair is ambiguous, add a short parenthetical to tell them apart.

## Length Budget

| | Figure |
|---|---|
| Typical entry | **≤1,300 characters** |
| Absolute maximum | **≤1,510 characters** |

The entry total is the **only** binding number. The per-field guidance above describes shape and content, not character maxima, so no combination of per-field limits can add up to a breach of the cap.

**It's a diagnostic, not a style preference.** An entry that can't be written inside the cap isn't one directive — it's two, or it's a pattern that belongs in `PATTERNS.md`. Measure from the `### DIR-NNN` heading to the start of the next heading.

## Directive Index

The Index is the reviewer's matching instrument, and the only part of `DIRECTIVES.md` read on every single review. Header form:

```
| ID | Title | Applies when (short) | Status |
|----|-------|----------------------|--------|
| DIR-NNN | <short title> | <trigger, ≤60 chars> | active |
```

## Worked Example

Illustrative only. `DIR-NNN` is a placeholder and can't collide with a live ID — replace it with the next free number.

```
### DIR-NNN — Hook registrations name their callbacks
- **Applies when:** A change registers a hook or event listener.
- **Status:** active
- **Rule:** A registration MUST reference a named callback defined in the layer that owns the behaviour. An inline closure or a function body defined at the registration site MUST NOT be introduced, and a registration MUST be appended at the end of its section rather than inserted mid-list.
- **Rationale:** A behaviour defined at its registration site cannot be tested, found, or replaced without editing the wiring.
- **Reviewer check:** Does every registration the change adds point at a named callback defined elsewhere, and does it sit at the end of its section?
- **Example:** Illustrative — `add_action( 'wp_footer', 'app_render_footer_marker' );` with the function defined in the helpers layer.
- **Added:** 2026-06-30 · **Source:** mission-20260630-01 · **Evidence:** [2026-06-30] — hook registration site defined behaviour
```

## One Copy Only — Don't Recreate The Drift

The Entry Template has a habit of breeding. It used to live in three places: this file, `DIRECTIVES.md`, and the `memory/reference/DIRECTIVES.md` seed inside `.opencode/memory.zip`. They drifted, and a fresh install went on to regenerate a format that had already been retired. The coupling that stops that happening again:

1. **This file is the only home** for the authoring steps, the Entry Template, the length budget, and the worked example.
2. **`DIRECTIVES.md` carries a one-line pointer here** in its `Format.` clause, and never restates the template, the field list, or the authoring steps. What it owns is the authority block, the three binding clauses, the Directive Index, the entries themselves, and the Retired Entries table.
3. **The `.opencode/memory.zip` seed** of `memory/reference/DIRECTIVES.md` carries the same authority block, the same three clauses, the same pointer, and empty Index / Directives / Retired sections — **no template, no field list, no retired `Scope` field**. A change to the format isn't finished until the seed's pointer still resolves and the seed still carries no template.
4. **Run both assertions below after any change to the format.** Use `/usr/bin/grep` rather than bare `grep`: the `grep` on a developer machine is often a wrapper that honours `.gitignore` and will silently skip paths, `.opencode/` included.

The Entry Template is identified by its placeholder form. From the repository root, this must return exactly one path — this file:

```bash
/usr/bin/grep -rl '^- \*\*Rule:\*\* <' --include='*.md' . \
  | /usr/bin/grep -v '/.opencode/memory/workspace/' \
  | /usr/bin/grep -v '/.opencode/memory/missions/'
# expected, exactly: ./.opencode/templates/reference/DIRECTIVES-TEMPLATE.md
```

And the archive seed must carry no trace of the retired `Scope` field or its glob phrasing:

```bash
unzip -p .opencode/memory.zip 'memory/reference/DIRECTIVES.md' \
  | /usr/bin/grep -cE '\*\*Scope:?\*\*|Scope specific|Scope glob|path or glob'
# expected: 0
```

That second assertion is keyed deliberately to the retired **field**, not to the word "Scope" on its own — the seed legitimately contains the phrase "Scope of binding" as the name of binding clause 1.
