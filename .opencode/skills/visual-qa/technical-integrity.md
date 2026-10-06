# Technical Integrity

What only a running browser can show: console errors, uncaught exceptions, failed requests, broken assets, mixed content, CSP violations, same-origin link status and in-page anchors. Links to other sites come from Bishop's link-check output in the brief. This file also covers SEO basics and performance, which are observations only.

## Before Each Page Loads

Where the browser tool supports an init script, install listeners before the page's own scripts run. Push each record onto `window.__qa`:
- `securitypolicyviolation` — record `blockedURI`, `violatedDirective`, `disposition`.
- `error` — registered in the capture phase (`addEventListener('error', fn, true)`), because resource load errors don't bubble; record the message for script errors and the element's `src` or `href` for resource errors.
- `unhandledrejection`.

An init script passed as a file goes in the run folder; the qa-guard plugin (`.opencode/qa-guard.ts`) confines path fields to `.opencode/memory/workspace/qa/` (only the key `sourcePath` may also point into `.opencode/skills/visual-qa/`). The qa-guard plugin does not inspect inline script content. Some browser servers take an init script only as a start-up option, not per call — then install the listeners after load as below.

Without init-script support, install the same listeners by script straight after load, and note in Coverage that early events may be missed. The console capture still records uncaught errors.

## Per Page

1. Navigate and settle the page (see `SKILL.md`).
2. **Console.** Read messages at warning level and above. Record errors, uncaught exceptions, CSP violations, mixed-content warnings and any browser "issues" the tool lists. Save to `console-<page>.txt` in the run folder.
3. **Network.** List requests. Record every failed request and every 4xx/5xx, including static assets: images, fonts, scripts, stylesheets. Save to `network-<page>.txt`. Read both lists before navigating away, because they reset.
4. **One read-only script** that returns:
   - the `window.__qa` records;
   - every link target: `a[href]`, `area[href]`;
   - every asset reference: `img` `currentSrc`, `srcset`, `script[src]`, `link[href]` (stylesheets and icons), `iframe[src]`, `source[src]`, `source[srcset]`, `video[poster]`;
   - `document.fonts` entries with status `error`;
   - images that are `complete` with `naturalWidth` 0 (broken);
   - `http:` resources on an `https:` page (mixed content);
   - every in-page fragment link, checked after the page has settled: match the raw id first, then the decoded id (`decodeURIComponent` inside try/catch — a malformed `%` throws), then `a[name]`; skip `#`, `#top` and empty fragments, which are always valid.
   Return counts plus the failures, not raw arrays — a large page's full inventory floods the context.
5. **Same-origin links.**
   - Same-origin means `new URL(href, document.baseURI).origin === location.origin`. Cross-origin URLs are never fetched in-page — the qa-guard plugin does not see in-page requests, so this rule is the only thing keeping them off other sites.
   - Check each same-origin URL once per run, not once per page, with `fetch(url, {method: 'GET', redirect: 'manual', cache: 'no-store'})`, at most 4 at a time and at most 200 per run; list the rest under Unverified (cap reached). Read the status, then cancel the body with `response.body?.cancel()` so large files aren't downloaded. The request carries the session's cookies — which is why the skip list matters.
   - Retry a 5xx once, after a short pause: a 5xx on both requests is a DEFECT; a 5xx once only is Unverified.
   - A response of type `opaqueredirect` (status 0) means the link redirects: record a redirect, target not visible, and never follow it. Redirect loops and hop counts can't be seen this way; they show only in the network list of a real navigation or in Bishop's link-check output.
   - A fetch that rejects (CSP `connect-src`, a network failure) is recorded as `fetch rejected` under Unverified, never as broken. An app service worker may answer instead of the server; say so if one is registered.
   - Never request anything on the skip list.
6. **Cross-origin links.** The browser cannot read their status: CORS hides it, and `no-cors` returns an opaque status 0. Use Bishop's link-check output from the brief. With no output, list them under `Unverified`.
7. **Reconcile.** One finding per URL, listing every page it appears on.

## Skip List — Never Request

This is a floor, not a complete list. Extend it with whatever the brief names. In doubt, don't request — report the URL as skipped.

- Schemes: `mailto:`, `tel:`, `javascript:`, `data:`, `blob:`.
- Any URL whose path or query contains, case-insensitively and as a substring, any of: `logout`, `log-out`, `log_out`, `signout`, `sign-out`, `sign_out`, `delete`, `remove`, `destroy`, `trash`, `spam`, `approve`, `activate`, `deactivate`, `revoke`, `disconnect`, `purge`, `flush`, `clear`, `empty`, `unsubscribe`, `opt-out`, `cancel`, `reset`, `confirm`, `checkout`, `add-to-cart`, `add_to_cart`, `publish`, `unpublish`, `restore`, `install`, `uninstall`, `enable`, `disable`, `dismiss`, `accept`, `reject`, `pay`, `buy`, `order`, `follow`, `vote`.
- Any URL carrying a nonce or token parameter (`nonce`, `_wpnonce`, `token`, `csrf`) or an action-style parameter (`action=`, `do=`).
- Report these as skipped, never as broken.

## Bishop's Link-Check Output

Before the first pass, Bishop runs whatever link checker is installed, read-only, and pastes its output into the brief. Grade it with the table below; don't re-run it.

Classify these as `Unverified`, never broken:
- bot protection (LinkedIn `999`, a Cloudflare `403` with `cf-mitigated`, challenge pages);
- `429` rate limiting;
- timeouts;
- auth-required responses (`401`/`403`, or a redirect to a login page).

A checker that used `HEAD` and got `403`/`404`/`405` proves nothing on its own. Unless a `GET` also failed, treat it as `Unverified`.

## Grading

| Category | Console and runtime | Network, assets and links |
|-------|---------------------|---------------------------|
| **DEFECT** | an uncaught exception or unhandled rejection from first-party code, on load or during a tested interaction; an enforced CSP violation that blocks a first-party script or style. | a failed page document, first-party script, stylesheet, web font used for visible text, or above-the-fold image; a failed first-party API call that leaves the UI broken; blocked active mixed content; a redirect loop seen in a navigation or the link-check output; a broken internal link — 404 or 410, or a 5xx that repeats on a second request; a broken external link in primary navigation or a primary call to action; a missing fragment target used by a table of contents or skip link. |
| **OBSERVATION** | a first-party `console.error` with no visible breakage; framework or hydration warnings; `console.warn`; CSP report-only violations. | passive mixed content the browser upgraded; internal links that redirect (hop count from the link-check output, when it has one); a favicon or touch-icon 404; an external link in body content verified dead by a `GET` 404 or 410; source-map 404s; other 4xx (400, 405, 408 and the like), with the status. |
| **Unverified** | — | bot-protected, rate-limited, timed-out or auth-required links; `ERR_BLOCKED_BY_CLIENT`; cross-origin links with no checker output. |

Unverified is not a grade — it is listed, as in `SKILL.md`.

The Unverified rules for link-check output apply to in-page fetch results too: 401, 403, 429, timeouts and rejected fetches are Unverified, never broken.

A brief whose acceptance criteria name an integrity rule — "no console errors", say — makes its failure a DEFECT whatever this table says, third-party sources included; the brief states the intent.

Without such a criterion, third-party noise is an OBSERVATION at most, and only when it affects the page.

## SEO Basics — Observations Only

Check per page with a read-only script:
- `<title>` present, non-empty, and unique across the pages checked
- `meta[name="description"]` present and non-empty
- `link[rel="canonical"]` present and absolute
- `<html lang>` set
- exactly one `<h1>`
- `meta[name="viewport"]` present
- `meta[name="robots"]`: note any `noindex` (expected on staging; say so)
- Open Graph `og:title`, `og:description` and `og:image` present, with `og:image` an absolute URL. The browser never loads `og:image`, so never fetch it in-page; verify it from Bishop's link-check output, otherwise list it under Unverified.

Every finding is an OBSERVATION unless the brief's acceptance criteria require it.

## Performance — Observations Only

With a performance-trace capability:
- record LCP, CLS, and INP when an interaction was tested, per page, at one desktop and one mobile width;
- with throttling available, add one slow-network run;
- note the largest resources and any image whose natural size far exceeds its rendered size.

Context thresholds, Core Web Vitals "good": LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1. Local and staging numbers are lab data, not field data; say so.

A single lab run is noisy; repeat a measurement before reporting a number.

A Lighthouse audit, where available, covers accessibility, SEO and best practices, not performance. Treat its items as leads to confirm by measurement.

Without a trace capability, write `Performance not measured — no trace capability` in Coverage.

## Reporting Integrity Findings

Each finding gives:
- the page(s) it was found on
- the resource URL
- the type: link, asset, console, CSP or mixed content
- the status or message
- the method: in-page fetch, network list, console, or link-check output
- the evidence path
- how often it reproduced (for example `2/2 loads`)

The method values here are kinds of `tool report` in `SKILL.md`'s Evidence vocabulary; also give the viewport width when it matters.

Group duplicates.

## What The Guard Doesn't See

In-page `fetch`, XHR and `window.open` from a page script pass no hook. The same-origin rule, `redirect: 'manual'` and the skip list are doctrine, not mechanism — follow them exactly.
