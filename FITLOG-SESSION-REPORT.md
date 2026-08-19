# FitLog — Session Report
**Date:** 2026-08-17 → 2026-08-19
**Goal:** Build a private, $0 iPhone gym PWA with daily workout plans, set-by-set completion, and auto rest timer.

---

## What We Started With

The user had a folder at `/Users/mohit/Desktop/Projects/fitlog/` containing a nearly-complete PWA called FitLog (formerly "Fitness Buddy"), authored in a previous session. The app:
- Is a single-file PWA built by `build.sh` from `head.html + core.html + eximg.html + tail.html`
- Ships with an exercise library (26+ built-in), routine templates, live session logging, auto rest timer, water tracking, food log, body weight, sleep, cardio, breathwork, measurements, weekly report, and notifiers
- Was already built for iOS PWA install (viewport meta, apple-touch-icon, manifest)

The user's original ask was: clone the repo, install on iPhone, fix anything broken.

---

## What Was Already Working

- `index.html` (built artifact, 415 KB) — valid HTML5 document
- Manifest, icons, viewport meta, apple-mobile-web-app meta — all in place
- Core JS (304K inline): state boot, seed migrations, coaching engine, swipe gestures, timers, vibration/beep, localStorage persistence, service worker registration
- `build.sh` — concatenates head/core/eximg/tail into `index.html`

---

## What Was Broken (Discovered This Session)

### 1. Smart/curly quotes in `core.html`
**Root cause:** A previous build pass introduced Unicode smart quotes (`'` U+2018, `'` U+2019, `"` U+201C, `"` U+201D) in exercise names, TIPS strings, and QUOTES strings. These are invisible look-alikes. They don't break rendering but they are NOT valid JS string delimiters — strict parsers (Node, strict mode) treat them as syntax errors. Safari on iPhone is lenient enough to tolerate them.

**Count in original:** 114 smart-single + 18 smart-double quotes

**Why it mattered:** `node --check` flagged them as syntax errors, which made the boot sequence unreliable. Even though the app rendered on iPhone, the seed-data JS strings with smart quotes could throw on cold start and abort the boot, leaving the DOM without any wired-up handlers.

**Fix:** Replaced all smart quotes with ASCII equivalents (`'` → `'`, `'` → `'`, `"` → `"`, `"` → `"`). Committed in `9ab4e8a`.

**Side effect:** After smart-quote replacement, some single-quoted strings that previously contained smart-quote apostrophes now contained ASCII apostrophes (e.g., `'Farmer's carry'`, `'child's pose'`, `'You don't...'`). These became broken JS strings. Fixed by switching those strings to backticks or double-quotes. The QUOTES and TIPS arrays were fully switched to backticks. Committed in `9ab4e8a`.

**Walker corruption (warning for future runs):** An earlier attempted fix used a character-walking script that was re-run multiple times between operations. Each pass introduced new artifacts (e.g., `"World\`s greatest stretch"` — a stray backtick). The walker was NOT idempotent and compounded damage. The final fix used a single-pass deterministic `sed` replacement (smart quotes only) plus targeted `Edit` calls for the three remaining broken strings.

### 2. Service Worker serving stale content (PRIMARY iPhone symptom)
**Root cause:** GitHub Pages was serving the `main` branch when the app was first installed as a home-screen PWA. The service worker (`sw.js`, cache name `fitlog-v21-iphone`) cached that older `main`-branch shell at install time.

When I later switched Pages to serve the `personal` branch, the network started delivering the new build — but the **already-running service worker on the phone kept serving the cached old shell**. The HTML came from the new build but the JS layer was stale: DOM nodes from the new build didn't have the event listeners the cached JS expected, so **nothing was clickable**.

This is the reason for "nothing is clickable in the app on iPhone."

**Evidence:**
- WebFetch of the live URL returned generic "Fitness Buddy" text (the main branch app) — Pages CDN was serving cached main content
- GitHub Pages status showed `last deployed 2 days ago` (before my commit) even after my push — the CDN was stale
- User screenshot confirmed Pages UI showed "personal" branch selected but with stale deploy timestamp

**Fix (commit `084e091`):** Commented out the service worker registration in `tail.html`. This removes the stale-cache path entirely. The app now always fetches fresh from the network. Service worker can be re-enabled later with a fresh cache name once the app is stable.

### 3. Stale deploy on GitHub Pages CDN
**Root cause:** GitHub Pages had a stale deploy of the `main` branch cached at the CDN edge. Even after switching the source branch to `personal` via the API, the CDN kept serving the old build for ~2+ days.

**Fix:** Pushed an empty commit (`cb2a73d`) to force a redeploy, then bumped the SW cache name (`4598737`), then disabled the SW entirely (`084e091`). The combination of new deploy + no SW ensures fresh content on next visit.

### 4. Personal seed data baked into the shipped build
**Root cause:** The `index.html` shipped with personal workout history (HIST array, H2 array), the user's return-workout push, weight journey (58→67→63.9 kg), supplement stack, BCA calibration, and injury notes — all in plaintext JS. Anyone who visited the hosted URL could read them.

**Fix:** Set `const PUB = true` in `core.html` line 457. Every seed function (seedV3, seedV4, seedV5, seedV7, seedV8, seedV9) has a `if(PUB){...return;}` guard that skips the personal data import when `PUB` is true. Generic defaults (exercise library, routine templates, quick-add foods via seedV2) still seed because they aren't personal. Committed in `9ab4e8a`.

---

## Current State (commit `084e091`)

| Item | Value |
|------|-------|
| Branch | `personal` (private — pushed to `mohitgpta96/fitlog`) |
| Latest commit | `084e091` |
| Pages URL | https://mohitgpta96.github.io/fitlog/ |
| Pages source | `personal` branch, `/` root |
| Service worker | **Disabled** (commented out in `tail.html`) |
| `PUB` flag | `true` (no personal seed data imports) |
| Smart quotes | All replaced with ASCII |
| Build size | 424,866 bytes (`index.html`) |

---

## How to Install on iPhone (fresh)

1. **Delete the old FitLog icon** from home screen (long-press → Remove App)
2. **Force-quit Safari** (swipe up in app switcher, swipe Safari off)
3. Open **https://mohitgpta96.github.io/fitlog/** in Safari
4. Tap **Share → Add to Home Screen**

The service worker being disabled means every visit fetches the latest build — no stale cache, no offline mode, but always fresh. If you want offline mode back later, we can re-enable the SW with a fresh cache name.

---

## What Still Needs Verification

1. **Buttons actually clickable on iPhone** — the SW disable fix is unverified by the user. If still broken after fresh reinstall, the next suspect is an actual JS runtime error on cold boot in Safari (different from Node strict-parse errors). Diagnose via Safari → Settings → Advanced → Web Inspector, then Console.app on Mac.
2. **Onboarding flow** — with `PUB=true`, first launch hits the `obStart()` onboarding card. Needs verification.
3. **Service worker re-enable** — once stable, uncomment the two lines in `tail.html`, bump the cache name, and redeploy for offline support.

---

## Technical Debt / Future Work

- Re-enable service worker with fresh cache name (e.g., `fitlog-v23-stable`)
- Consider using `navigator.serviceWorker.register` with `{scope: './'}` and proper cache busting on deploy
- The `.claude/` config files (settings.json, hook, agent, CLAUDE.md append) are committed to git — these are local-only tooling configs and shouldn't be in the repo (they don't affect the app, just the Claude Code session)
- Replace `index.html` build artifact in git with a `.gitignore` entry — only `core.html` and build script should be versioned

---

## Commits on `personal` branch (chronological)

| Commit | Message |
|--------|---------|
| `9ab4e8a` | personal: PUB=true, no personal seed data, smart-quote fix |
| `cb2a73d` | trigger: force GitHub Pages redeploy (empty commit) |
| `4598737` | chore: bump SW cache name to v22-personal to bust stale main-branch cache |
| `084e091` | fix: disable service worker to bust stale cache on iPhone |
