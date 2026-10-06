# Accessibility — WCAG 2.2 AA

The target is WCAG 2.2 Level AA. Checks come in three layers: an automated engine, where available; criteria Ripley measures herself; and criteria only a human or screen reader can judge. A clean automated run is not a pass. Every report carries the standing Coverage line from `SKILL.md`.

## Automated Engine — If Available

- If the browser server offers an accessibility audit (Lighthouse's accessibility category, for example), or the operator has supplied an engine script such as axe-core in the run folder, run it.
- An engine script the operator supplies goes in `.opencode/memory/workspace/qa/` (the run folder doesn't exist until you make it). Run it by passing its content inline to the page-script tool, or by `sourcePath` where the tool reads a file. Injecting it is a sanctioned exception to the read-only rule in `SKILL.md`.
- Never load an engine from a CDN. The qa-guard plugin (`.opencode/qa-guard.ts`) does not stop a script tag or an in-page fetch, and a staging site may have no CSP — this is doctrine: never do it.
- With axe-core, use the tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`, and keep `incomplete` results. Those need follow-up by measurement, or go under Needs human review.
- Automated engines catch roughly half of accessibility issues by volume (Deque's 2021 study puts axe-core at 57%). They are a first layer, not a verdict.
- With no engine available, write `No automated accessibility engine` in Coverage. The measured checks still run.

## Criteria Ripley Measures

| SC | Level | Threshold | How to check |
|---|---|---|---|
| 1.4.3 Contrast (Minimum) | AA | 4.5:1; large text (≥ 24 px, or ≥ 18.66 px at weight ≥ 700) 3:1; no rounding — 4.499:1 fails | Computed text and background colours. Composite semi-transparent layers (including element and ancestor `opacity`) over the first opaque ancestor background. For a gradient, use the worst stop under the text. Check every state (rest, hover, focus). Exempt: disabled or inactive components, decorative text, logotypes, incidental text. Image backgrounds and text shadows go under Needs human review unless sampled. |
| 1.4.11 Non-text Contrast | AA | 3:1 against adjacent colours | Computed colours of input borders, meaningful icons, focus indicators and state changes. Include element and ancestor `opacity`, and check every state (rest, hover, focus). Exempt: inactive components, and boundaries not needed to identify the control. |
| 1.4.10 Reflow | AA | 320 CSS px wide: no horizontal page scroll and no clipped content; content that scrolls horizontally is checked at 256 CSS px tall | The responsive checks at 320. Two-dimensional content (data tables, maps, code, toolbars) is exempt. |
| 1.4.12 Text Spacing | AA | line height 1.5×, paragraph spacing 2×, letter spacing 0.12×, word spacing 0.16× — all of the font size | Apply line height 1.5 × font size, paragraph spacing (space after paragraphs) 2 × font size, letter spacing 0.12 × font size and word spacing 0.16 × font size, each with `!important`. Flag text clipped (an element's `scrollHeight` over `clientHeight` + 1, or `scrollWidth` over `clientWidth` + 1, where overflow is hidden or clipped) or overlapping (text rects intersecting). Reload afterwards. |
| 1.4.4 Resize Text | AA | 200% without loss of content or function | Halve the viewport width and set the root font size to 200% (a temporary style override — reload afterwards). Text sized in px needs true browser zoom: list it under Needs human review. |
| 1.4.13 Content on Hover or Focus | AA | dismissible, hoverable, persistent | Hover or focus the trigger; `Escape` dismisses without moving the pointer; the content stays open while hovered. |
| 2.1.1 Keyboard | A | every function operable by keyboard | Keyboard sweep below. Activate with `Enter` and `Space` only controls that are safe — see the sweep. |
| 2.1.2 No Keyboard Trap | A | focus can always leave | `Tab`, `Shift+Tab` and `Escape`. A modal that holds focus but closes on `Escape` is not a trap. |
| 2.4.3 Focus Order | A | a meaningful order | Compare the focus sequence with the visual reading order. |
| 2.4.7 Focus Visible | AA | a visible indicator | Computed outline, box shadow, background or border differ between focused and unfocused. |
| 2.4.11 Focus Not Obscured (Minimum) | AA | not entirely hidden by author content | Scroll the focused element into view first. Check `document.elementsFromPoint` at its corners and centre, and the rects of fixed and sticky elements above it — `elementsFromPoint` skips overlays with `pointer-events: none`. Covered points only justify a closer look. It fails only when the element is entirely covered by author content; confirm with an element screenshot. Partial cover passes AA. |
| 2.5.8 Target Size (Minimum) | AA | 24 × 24 CSS px, or the spacing exception for undersized targets | Rects of interactive elements at 320, 375 and one desktop width. A target under 24 × 24 CSS px passes only if a 24 px-diameter circle centred on its box doesn't come within the circle of another undersized target and its centre is at least 12 px from every other target's rect. Inline, equivalent, user-agent and essential exceptions go under Needs human review. |
| 2.4.1 Bypass Blocks | A | a skip link or a `main` landmark | Snapshot or DOM. |
| 2.4.2 Page Titled | A | a `<title>` present and non-empty | DOM. Whether it's descriptive goes under Needs human review. |
| 3.1.1 Language of Page | A | `<html lang>` set to a valid BCP 47 value | DOM. |
| 1.1.1 Non-text Content | A | every meaningful image has alternative text; decorative ones have `alt=""` | DOM. |
| 1.3.1 Info and Relationships | A | labels tied to fields, headings in order, landmarks, table headers | Snapshot or DOM. |
| 2.5.3 Label in Name | A | the accessible name contains the visible label | Snapshot. |
| 4.1.2 Name, Role, Value | A | interactive elements expose name, role and state | Snapshot. |
| 2.2.2 Pause, Stop, Hide | A | moving, blinking, scrolling or auto-updating content that starts automatically and lasts over 5 s has a pause, stop or hide control | Measure where possible: `document.getAnimations()` for CSS and Web Animations, and repeated DOM reads over 10 s for carousels and tickers. Two screenshots 6 s apart are vision-only triage. |
| 1.3.4 Orientation | AA | content not locked to one orientation | Check at a portrait and a landscape viewport of the same device size. |
| 1.3.5 Identify Input Purpose | AA | fields collecting user data carry a valid `autocomplete` token | DOM: compare each personal-data field's `autocomplete` against the HTML token list. |
| 2.4.4 Link Purpose (In Context) | A | every link has an accessible name | Snapshot. Whether the purpose is clear in context goes under Needs human review. |
| 3.3.1 Error Identification | A | input errors identified and described in text | Submit invalid input on a non-production form whose action matches nothing on the skip list in `technical-integrity.md`; the error appears as text tied to the field. |
| 3.3.2 Labels or Instructions | A | inputs have labels or instructions | Snapshot or DOM. |

Criteria not in this table are not evaluated. Every report lists, under Unverified: `WCAG 2.2 AA criteria not in accessibility.md were not evaluated.`

## Keyboard Sweep

1. Count focusable elements — reachable by `Tab`: `tabindex` ≥ 0, not disabled, visible, including inside iframes the tool can reach. Press `Tab` up to that count plus 5, with a cap of 150.
2. After each press, read `document.activeElement`: its role, accessible name, rect, and whether its focus style differs.
3. Never activate a control whose accessible name or target matches the skip-list words in `technical-integrity.md`. Activate navigation, disclosure, tab, menu and form controls the brief marks safe; in doubt, focus without activating and report it.
4. Report focusable elements never reached, and jumps that reverse reading direction by more than one row.
5. Press `Shift+Tab` for 10 stops. Press `Escape` in any open dialog.
6. Take element screenshots of the first 10 stops, plus any suspicious stop.

## Human Or Screen Reader Only

List these under `Needs human review`; never grade them:
- alt-text quality (1.1.1)
- caption and audio-description accuracy (1.2.x)
- reading sequence as announced (1.3.2)
- use of colour alone to convey meaning (1.4.1)
- whether headings and labels are descriptive (2.4.6)
- whether error suggestions are useful (3.3.3)
- whether status messages are announced (4.1.3)
- how ARIA widgets behave in real screen readers
- accessible authentication (3.3.8)
- gesture and drag alternatives in context (2.5.1, 2.5.7)

## Grading

- A measured failure of an A or AA criterion is a DEFECT.
- Below a design-stated AAA target is a DEVIATION.
- Engine `incomplete` items that can't be settled by measurement go under Needs human review.
- Each finding gives the Evidence fields from `SKILL.md` — URL, viewport width, state, reference (here the criterion, level and threshold), measured value against threshold, method, evidence path — plus the selector.
- A finding that rests on vision alone is an OBSERVATION or goes under Needs human review; it becomes a DEFECT only with a measured corroboration.
