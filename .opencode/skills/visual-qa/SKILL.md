---
name: visual-qa
description: "Conducts rigorous visual, functional, accessibility and technical-integrity QA of web pages in a non-production environment. Trigger when the brief requests a QA pass or re-verify and supplies a target URL, design reference or acceptance criteria, and browser choice."
---

# Visual QA

This is how Ripley does the work. Where she sits in a mission, passes and re-verifies, and how verdicts are handled are canonical in `.opencode/skills/mission-lifecycle/SKILL.md` → QA Verification. Her conduct is in `.opencode/agents/ripley.md`. Read the sibling file when you reach its phase.

## The Order Of Work

1. Read the brief and check it carries these contents (brief contents, not the pre-flight gate — Bishop clears that):
   - target URL and named non-production environment
   - design reference or acceptance criteria
   - which browser to use
   - the pass label (`QA pass — initial` or `QA re-verify N of 2`)
   - Bishop's link-check output, or a statement that no checker is installed

   Anything missing → stop and report to Bishop.

2. Capability check.
3. Make the run folder `.opencode/memory/workspace/qa/<run-id>/`, where `<run-id>` is `YYYYMMDD-HHMM-<label>` in UTC (for example `20261002-1530-initial` or `20261002-1610-reverify-1`). Every file you or a browser tool writes goes there, with an explicit path.
4. Settle the page.
5. Visual fidelity.
6. Functional flow.
7. Responsive behaviour.
8. Technical integrity → `technical-integrity.md`.
9. Accessibility → `accessibility.md`.
10. Design comparison, only when the brief supplies a design source → `design-comparison.md`.
11. Grade, then report.

## Capabilities, Not Products

Ripley needs capabilities, not a particular product. The playwright MCP server's browser tools provide them.

| Capability | Required | Playwright MCP |
|---|---|---|
| Open a URL | yes | a browser navigation tool |
| Set the viewport size | yes | a viewport resize tool |
| Screenshot a viewport or element to a named file | yes | a screenshot tool |
| Accessibility or DOM snapshot | yes | a snapshot tool |
| Run read-only JavaScript and return values | yes | a script-evaluation tool |
| Keyboard input | yes | a key-press tool |
| Click, hover, type, fill forms | yes | pointer and form-input tools |
| Console messages, errors included | yes | a console-messages tool |
| Network requests with status codes | yes | a network-requests tool |
| Colour-scheme and reduced-motion emulation | no | a media-emulation tool, where available |
| Network and CPU throttling | no | a throttling tool, where available |
| Performance trace | no | a trace tool, where available |
| Lighthouse audit | no | a lighthouse tool, where available |
| Read a design source | no | a design MCP's read tools, such as Figma's `get_screenshot`, `get_metadata`, `get_variable_defs` — see `design-comparison.md` |

Tool names change between releases and tool registries. Map each required capability to a tool from the playwright MCP server's browser tools, by whatever names your tool list shows them. Never assume a hard-coded name form.

## Capability Check — Before Anything Else

- List the browser tools you actually hold. Map each required capability to one.
- A required capability missing → stop. Report to Bishop which capability is missing and what kind of server would provide it. Never fall back silently.
- Browser choice and screenshot-only review follow the canonical rules in `.opencode/skills/mission-lifecycle/SKILL.md` → QA Verification. Record the mode you used in the report's setup line.
- Record the server(s) used, the browser engine if shown, and the capability-to-tool map. They go in the report.

## Settle The Page Before Judging It

- Wait for something that means "ready": an element or text from the brief, or the page's main content. Don't use a fixed sleep. Network idle is a last resort.
- Fonts: `document.fonts.status` reading `loaded` only means pending loads finished — it reads the same when no web font was requested. To check the intended face, look for a `FontFace` in `document.fonts` with that family and status `loaded` — that is the real test; `document.fonts.check()` alone is not, because it returns true for a family that was never declared. Note any entry with status `error` for technical integrity. The face actually used is visible only through a platform-fonts query, which most tools don't expose; without one, report the rendered face as `vision` or Unverified, never `measured`.
- Lazy content: scroll to the bottom in steps and back to the top before judging a page. Wait until images report `complete` with a non-zero `naturalWidth`.
- Motion: use reduced-motion emulation where available. Otherwise note that animations may differ between captures.
- Consent banners and overlays: test them once as part of the flow, then dismiss them for the rest of the run and say so.
- Record what you did to settle each page.

## Measure, Don't Eyeball

- Exact values come from the page: colour, size, spacing, font family, size, weight, line height, letter spacing. Read them with `getComputedStyle` and `getBoundingClientRect` through read-only JavaScript, or a CSS-inspection tool where the server has one.
- Screenshots are evidence and triage. Never report a colour value, pixel distance or font size read off an image.
- Images are downscaled before the model sees them; a tall full-page capture can arrive at well under half scale. Judge from viewport and element captures. Save full-page captures to a file only. Never pull an image taller than about 8,000 px into context; an oversized image can break the session.
- Page scripts you run are read-only. They read values and return them, and never change the DOM, storage or application state. Sanctioned exceptions, and only these: the event listeners and `window.__qa` record and the same-origin link fetches in `technical-integrity.md`; injecting an accessibility engine; and the temporary style overrides for text spacing and text resize in `accessibility.md` — reload after those.

## Visual Fidelity

Walk through the design reference or supplied mockup and verify each area:

- [ ] **Layout and alignment** — rects of key regions against the reference; overlaps and unintended gaps.
- [ ] **Spacing** — computed margin, padding and gap against reference values or tokens.
- [ ] **Typography** — the intended font face loaded (see Settle The Page), size, weight, line height and letter spacing against the reference.
- [ ] **Colour** — computed text, background and border colours against the reference or tokens. Check light and dark if both are designed.
- [ ] **Imagery** — rendered size and aspect ratio against the natural size of `currentSrc` (srcset, sizes and `<picture>` change which file loads at each width); not stretched; not blurry — `naturalWidth` of `currentSrc` at least rendered width × `devicePixelRatio`, checked after the viewport is set. Many automation browsers run at `devicePixelRatio` 1, so a pass there is weak evidence for high-density screens. CSS background images and SVG are outside this test.
- [ ] **Borders, radius, shadow** — computed values against the reference.
- [ ] **Content** — no placeholder or broken text: lorem ipsum, `TODO`, `undefined`, `NaN`, `[object Object]`. No truncation the design doesn't show.

Without a reference value to measure against, a visual judgement is at most an OBSERVATION, never a DEVIATION. Measured breakage needs no reference — horizontal page scroll, clipped text, content hidden under a sticky element. It is a DEFECT when it blocks an acceptance criterion or a WCAG criterion, otherwise an OBSERVATION.

## Functional Flow

Walk through the acceptance criteria and verify the flow:

- [ ] **Navigation** — menus open and close; links go where they should; breadcrumbs, tabs and steps work; back and forward behave.
- [ ] **Forms** — labels tied to fields; validation blocks bad input with a clear inline message; submit works. Submit only against the non-production backend the brief names.
- [ ] **Interaction states** — hover, focus, active and disabled are visible and distinct.
- [ ] **Loading, empty and error states** — trigger them where the tools allow (throttling, offline, the empty data the brief describes). Never left blank or stuck.
- [ ] **Modals and overlays** — open, close by button and `Escape`, focus held inside while open and returned on close.
- [ ] **Acceptance criteria** — walk each one in the brief, step by step, and record pass or fail per criterion.

## Responsive Behaviour

Default widths: `320, 375, 768, 1024, 1280, 1440, 1920`, plus the project's own breakpoints and 1 px either side of each when the brief or the CSS gives them. Height is 800 unless the brief says otherwise.

320 is the WCAG reflow floor — see `accessibility.md`.

After setting the size, confirm `window.innerWidth` matches. Some tools resize the window rather than the viewport.

At each width, a checklist:

- [ ] no horizontal page scroll (`document.documentElement.scrollWidth` greater than `clientWidth`), and no clipped overflow — flag any element whose `getBoundingClientRect().right` exceeds `innerWidth`, or whose own `scrollWidth` exceeds its `clientWidth` while its overflow is hidden or clipped. `overflow-x: hidden` on `html` or `body` hides the scrollbar, not the bug.
- [ ] clean reflow
- [ ] text readable and unclipped
- [ ] images scale
- [ ] navigation collapses as designed
- [ ] sticky and fixed elements hide no content
- [ ] touch targets per `accessibility.md`

One viewport screenshot per width, named `<width>-<page>.png`.

## Grading

Use the verdict vocabulary exactly. Severity is yours alone. Verdict handling is in `.opencode/skills/mission-lifecycle/SKILL.md` → QA Verification.

- **DEFECT** — the intent is not met: broken function, lost content, a blocked task, a failed acceptance criterion, a measured WCAG 2.2 A or AA failure, or a technical-integrity blocker as defined in `technical-integrity.md`.
- **DEVIATION** — it works, but differs from the reference beyond the tolerance stated in the brief or `design-comparison.md`. Needs a reference value. Contrast below a design-stated AAA target is a DEVIATION; below AA it is a DEFECT.
- **OBSERVATION** — non-blocking. Covers visual judgements with no reference value, minor technical items, performance notes, SEO basics, and code-level suspicions for `@apone`, named and not graded.
- **PASS** — meets intent. Always list what was covered; never just "no issues".
- **Not grades, but always reported:**
  - `Unverified` — what couldn't be checked, and why; for example, cross-origin links with no link-check output.
  - `Needs human review` — for example, what a screen reader announces, or content quality.

## Evidence

Every DEFECT and DEVIATION cites: the URL; the viewport width; the state (hover, focus, error…); the reference (frame, section, criterion or token); the measured value against the expected value; the method (`measured`, `vision` or `tool report`); and the evidence file path(s) in the run folder.

File names: `<width>-<page>-<what>.png`, `console-<page>.txt`, `network-<page>.txt`.

Read the console and network lists before navigating away; most tools reset them on navigation.

Before citing a saved file, confirm it landed in the run folder — some tools resolve file names against their own output directory.

**Example:**

> **DEVIATION — Primary button colour.** URL `http://localhost:3000/signup`, 375 px, rest state. Reference: design frame "Signup — Mobile", token `--color-primary` `#2563EB`. Measured: computed `background-color` `rgb(30, 64, 175)` (`#1E40AF`). Method: measured. Evidence: `qa/20261002-1530-initial/375-signup-button.png`.

## How To Report

1. The files-written line, as defined in `.opencode/agents/ripley.md`. It includes files a browser tool wrote.
2. A setup line covering: browser server(s); mode (isolated automation browser or screenshot-only as authorised); environment; target URL; reference; pass label.
3. The capability-to-tool map.
4. Findings under grade headings, only grades that have findings, in the format defined in `.opencode/agents/ripley.md`.
5. `### Unverified`, then `### Needs human review`, each only when it has entries.
6. `### Coverage` — pages × widths × areas checked, ending with exactly: `Automated and agent checks only; no screen-reader or content-quality review was performed.`

## Re-Verify Passes

A re-verify re-checks each finding the fix addressed, then makes a short regression sweep of the same pages at the same widths. Its report says which earlier findings are now closed, still open, or changed. Passes and re-verifies are defined in `.opencode/skills/mission-lifecycle/SKILL.md` → QA Verification. The regression sweep is defined here, not in the lifecycle; that is deliberate.
