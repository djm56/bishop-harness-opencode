# Design Comparison

Run this only when the brief supplies a design source — a design-tool server, exported frame images, or a specification with values. Use read tools only. This is doctrine only — the qa-guard plugin (`.opencode/qa-guard.ts`) doesn't stop a design tool's write tools (Figma's `generate_figma_design` or its Code Connect writers, for example). The brief names which read tools are permitted.

## What To Fetch

- Per breakpoint frame, fetch:
  - the geometry (positions and sizes of layers)
  - the tokens or variables (colour, spacing, typography)
  - one reference image
- Add per-node detail only where geometry and tokens can't settle a question.
- Record the design file's version, and reuse what you fetched while the version is unchanged. Design servers rate-limit read calls.
- Figma's server, for example, provides `get_metadata` (geometry), `get_variable_defs` (tokens), `get_screenshot` (reference image) and `get_design_context` (per-node detail). Any equivalent will do.
- With exported images only, you can triage visually. A measured comparison needs values from a specification. Without values, mismatches are OBSERVATIONs.
- Save each reference image in the run folder as `<width>-<page>-ref.png`.

## Map The Design To The Page

- Set the viewport width to the frame width. Measure page positions relative to the page root's rect, and design positions relative to the frame's origin.
- Pair design nodes with page elements, in this order of reliability:
  1. an explicit attribute developers add (for example `data-design-node`)
  2. a component mapping the design tool provides
  3. exact text content for text nodes
  4. layer name against a test id
  5. the nearest geometric match within 8 px, flagged as low confidence
- Compare tokens, not just values. Read CSS custom properties with `getComputedStyle(document.documentElement).getPropertyValue('--token-name')`. The wrong token is a DEVIATION even when the colour happens to look right.
- Translate units:
  - letter spacing in % → em ÷ 100
  - line height in % → multiply by the font size
  - note the design file's colour profile, since a P3 file's values differ from sRGB
- Computed `line-height: normal` has no numeric value — measure a rendered text line's height instead.
- Computed `letter-spacing` comes back in px; divide by the font size to compare with em.
- A reference image may be exported at 2× — divide by its scale before comparing sizes.
- Dynamic text defeats exact-text pairing; use another method for it.

## Tolerances — Defaults, Calibrate First

- Geometry, per edge:
  - up to 0.5 px — ignore
  - up to 2 px — OBSERVATION
  - over 2 px, or a changed line wrap — DEVIATION
- Typography: family, size and weight exact; line height ±1 px; letter spacing ±0.01 em.
- Colour: exact against the token value. Colour in images is visual triage only.
- Tolerances in the brief override these.
- These defaults are a starting point, not a standard. Calibrate them against one page known to be correct before relying on them.

## Pixel Comparison

Ripley has no shell, so no pixel-diff tool. Comparing a design crop with a page element screenshot by eye is triage only. It is never a finding on its own: confirm by measurement, or report it as `vision`.

## Reporting Mismatches

Each mismatch gives:
- the design node (link, id or name)
- the page selector
- the property
- expected (value and token name)
- actual (computed value)
- the delta
- the viewport width
- pairing confidence
- evidence: the design reference image and the page element screenshot

Group findings by component, so one wrong token isn't reported forty times.
