# Menu-bar icons not appearing — investigation handover

**Date:** 2026-06-15
**Branch:** `stacked-squash` (fast-forwarded build with stacked-text + upstream memory-leak fix)
**Status:** UNRESOLVED. Root cause located but not fixed. Many theories disproven — read these first to avoid retreading.

---

## TL;DR

CodexBar's menu-bar status items (codex + claude, `mergeIcons=0`) are **created and marked visible but never get a slot in the macOS menu bar** — they sit at the macOS "unplaced" sentinel. **Every other menu-bar app on the same machine places fine.** So the environment can place items; CodexBar's uniquely fail. This started after fast-forwarding to the upstream code that added a macOS-26-Tahoe menu-bar "placement recovery" subsystem. The single most likely untested fix is **reboot with the recovery churn disabled** (see Next Steps).

---

## Environment (critical — this is not a normal desktop)

- **Headless Mac mini (Apple Silicon)**, normally driven via **Jump Desktop** from an **M4 MacBook Air**. A physical display was attached only to log in this session.
- **macOS 26 "Tahoe"** (Darwin 25.5.0). This matters: the broken code is Tahoe-specific.
- Jump Desktop renders a **black bar at the top** (notch emulation for the Air's notch) → unusual menu-bar geometry.
- Display resolution changed during testing: **1470×922** (scaled, default) and **2936×1840** (native). Bug reproduces at both.
- **Bartender 6** installed (intermittently running). **uBar** taskbar at the screen bottom. **Hammerspoon on the Air** (not the Mini) suppresses the Air's own CodexBar "bottom-of-screen popup" — i.e. the same bug, worked around there.
- **No full Xcode on the Mini** — only Command Line Tools. (The "working" Mini binary was the Air's Xcode-built **legacy** app that came with the repo clone.) User installed Xcode this session but **license not accepted** → toolchain now errors; build with `DEVELOPER_DIR=/Library/Developer/CommandLineTools`.
- Bundle id `com.steipete.codexbar`; app at `/Users/petersmini/Projects/CodexBar/CodexBar.app`.
- Build: `DEVELOPER_DIR=/Library/Developer/CommandLineTools CODEXBAR_SKIP_WIDGET=1 ./Scripts/compile_and_run.sh` (skip-widget because no Xcode).

## History (per user)

- Fork fixed a memory leak; upstream also fixed it → they **fast-forwarded** → icons disappeared on **both** the Mini (CLT build) **and** the Air (Xcode build).
- **Legacy** build (with the leak) still **works on the Air** (physical display). Never tested legacy on the Mini.
- Goal: get the **fast-forwarded** build (leak-fixed + stacked text) to show icons.

---

## CONFIRMED facts (with evidence)

1. **Items are created + flagged visible but unplaced.** `NSStatusItem VisibleCC codexbar-codex=1`, `…-claude=1`. AX reports both at **x=7, y=(screen_height−1)**, overlapping. `y` tracks screen height (921 at 922-tall, 1839 at 1840-tall) → it's a *not-placed sentinel*, not a real coordinate. Per CodexBar's own `isBlockedSnapshot`: button exists but **no window / zero width** = "blocked".
2. **CALIBRATION (decisive):** every other app places at **y=3** (top of bar): Spotlight, Rectangle, OneDrive, JumpConnect, LinearMouse. Only CodexBar is at the sentinel. → the environment places items fine; **CodexBar is uniquely broken.**
3. **Zero visible contribution.** Clock-excluded quit-diffs (CodexBar running vs quit) are byte-identical → the items render nothing anywhere on the bar. (The bottom-left "icons" are uBar, not CodexBar.)
4. **macOS flagged it as blocked.** `hasShownTahoeAllowListGuidance=1` (+ timestamp) — CodexBar's Tahoe code already concluded macOS is hiding the icon and showed the "enable in System Settings → Menu Bar" alert (user missed it; headless).
5. **A written Preferred Position gets wiped on launch even with Bartender off** (set 1180/1240, both < the preflight's 1982 clear-threshold). So CodexBar/macOS wipes it, not Bartender.

---

## DISPROVEN theories (do NOT retread — each was killed by a direct test)

| # | Theory | How it was disproven |
|---|--------|----------------------|
| 1 | `StackedTextStatusView` Auto-Layout bug (TAMIC=false + manual frame) | Real latent bug, **fixed**, but **not the cause** — percent mode fails identically; rebuild changed nothing. |
| 2 | Stacked-text-specific rendering | **Percent mode also fails** (clean quit-diff). Not mode-specific. |
| 3 | Menu-bar overflow / full bar | ~490pt empty gap; bar far from full; other apps fit. |
| 4 | Bartender actively hiding | **Fully quit Bartender → still sentinel.** Bartender's config has **zero** codexbar entries (doesn't track them). |
| 5 | Code signature (adhoc vs stable) | **Re-signed** bundle with stable `CodexBar Development` cert (Authority verified) → still sentinel. |
| 6 | Display resolution / width | Tested 1470 and 2936 wide → sentinel at both; other apps fine at both. |
| 7 | Persisted `NSStatusItem VisibleCC` defaults | Deleted them (backed up) → no change; app recreates `=1`. |
| 8 | Bartender wiped the Preferred Positions | Positions wiped with **Bartender fully off**. |
| 9 | The Tahoe recovery **churn** is the live blocker | **Disabled all 4 entry points + rebuilt → still sentinel.** Churn isn't the *live* blocker (but may have left **persistent** corruption — see Next Steps). |
| 10 | Clean Tahoe per-app allow-list block | `com.apple.controlcenter` `MenuBarCustomizationState` shows no clean CodexBar block; `killall ControlCenter` didn't recover. |
| 11 | Multiple items vs single (`mergeIcons`) | **Merged single item also fails.** Not a multi-item problem. |
| 12 | Control Center restart clears it | `killall ControlCenter` + relaunch → still sentinel. |

---

## The actual mechanism (located, not fixed)

The fast-forward added a **macOS-26 Tahoe menu-bar "recovery" subsystem**:
- `MenuBarStatusItemPlacementPreflight` — clears "suspicious" saved positions (`>maxX+512` or `<=0`) on every `makeStatusItem`.
- `MenuBarStatusItemDefaultsRepair` — run-once (`hasRepairedHiddenStatusItemVisibilityDefaults`) clears `VisibleCC=0` keys.
- `MenuBarStatusItemWindowProbe` — `CGWindowList` probe; `isTahoeBlockedProxy`.
- `MenuBarVisibilityWatcher` — 2s after launch, if items look "blocked", **recreates** them; same on every screen-parameters change. **Its own comment (line ~408): repeated NSStatusItem destruction "corrupts Control Center."**

On the headless/Jump Tahoe Mini the items can't get a slot initially → this code **recreate-loops** them → corrupts Control Center → items stay unplaced. The legacy build has none of this and just lets macOS place items (works on the Air's physical display).

**Open question the disable-test raised:** disabling the churn did NOT immediately fix it → the corruption is likely **persistent** in Control Center (a reboot *while churn was active* just re-corrupted). Untested: reboot *now* that churn is disabled.

---

## State changes made this session (to RESTORE or DECIDE on)

**Code edits (in working tree — user plans to reset; keep or revert deliberately):**
- `Sources/CodexBar/StackedTextStatusView.swift` — TAMIC fix (real latent bug, unrelated to this issue).
- `Sources/CodexBar/StatusItemController+Animation.swift` — thickness-guarded centering in `installStackedTextView` (same).
- `Sources/CodexBar/StatusItemController.swift` — **DISABLED 4 placement-subsystem call sites** (preflight, defaults-repair, startup visibility check, screen-parameters observer), each marked `// DISABLED (Tahoe recovery regression)`.

**System / defaults:**
- Bartender 6: **quit** (left off to avoid confounds — restart when done). uBar: relaunched.
- `mergeIcons` → `false` (restored). `menuBarDisplayMode` → `stackedText` (restored).
- `NSStatusItem` defaults churned; **backup at `~/.agent-migrations/codexbar-defaults-backup.plist`** (restore: `defaults import com.steipete.codexbar <file>`).
- App re-signed with self-signed `CodexBar Development` cert (in login keychain, **untrusted**; codesign used via `-A` key access). Cert material in `/tmp/codexbar-dev.*`.
- Xcode installed but license unaccepted → use `DEVELOPER_DIR=/Library/Developer/CommandLineTools` or run `sudo xcodebuild -license accept`.

---

## Recommended NEXT STEPS (in order)

1. **REBOOT the Mini with the churn-disabled build running.** Cheapest decisive test of the persistent-Control-Center-corruption hypothesis (prior reboots were with churn *active*). If icons return → that was it.
2. **If still broken: legacy-binary test on the Mini** (the definitive code-vs-environment split). Copy the Air's working legacy `CodexBar.app` over (SSH/scp), or build the pre-subsystem legacy code, and run on the Mini:
   - Legacy **places** → it's the new code → revert the whole subsystem properly (commits `6665d028`, `e6d61a8d`, `8545c76d`, `55c0a105` — note `e6d61a8d` also changed item-creation in `StatusItemController` ~35 lines beyond the call sites; the call-site disable this session was **not** a full revert).
   - Legacy **fails** → it's the Tahoe/headless environment → workaround: keep a real/dummy-HDMI display attached at login, or escalate upstream.
3. **Check upstream `steipete/CodexBar`** for newer menu-bar-placement fixes (this fork is behind; the subsystem is actively churning per git log).
4. Consider whether Tahoe requires a display present at status-item-creation time on headless Macs (app launches at login; Jump connects after — menu bar may not be ready).

---

## Reusable diagnostic techniques

- **Placement check:** `osascript -e 'tell application "System Events" to tell process "CodexBar" to get position of every menu bar item of menu bar 2'` → `…, 3` = placed; `7, <screen_height−1>` = unplaced sentinel.
- **Calibrate** vs other apps: enumerate menu-bar items across `every process whose background only is true`.
- **Visibility (immune to icon ambiguity):** clock-EXCLUDED quit-diff — screenshot the status region (NOT the clock) with CodexBar running vs quit; `cmp`/`md5` identical = contributes nothing. ⚠️ The clock and dynamic icons (wifi, recording dot) cause **spurious md5 diffs** — always exclude the clock and confirm visually.
- **Don't eyeball CodexBar's icons** — it reuses the real ChatGPT/Claude brand logos; indistinguishable from those apps. This caused two false reads this session.
- Relevant defaults: `com.steipete.codexbar` (`NSStatusItem VisibleCC *`, `hasShownTahoeAllowListGuidance`, `hasRepairedHiddenStatusItemVisibilityDefaults`); `com.apple.controlcenter` (`MenuBarCustomizationState`).

## Key code references

- `Sources/CodexBar/MenuBarVisibilityWatcher.swift` — Tahoe recovery (`isBlockedSnapshot`, `startupRecoveryAction`, recreate/refresh, `presentGuidance` w/ the "Allow in the Menu Bar" text).
- `Sources/CodexBar/MenuBarStatusItemPlacementPreflight.swift` — position clearing.
- `Sources/CodexBar/MenuBarStatusItemDefaultsRepair.swift` — run-once visibility repair.
- `Sources/CodexBar/MenuBarStatusItemWindowProbe.swift` — `CGWindowList` probe.
- `Sources/CodexBar/StatusItemController.swift` — `makeStatusItem` (~273), `init` (~369), `updateVisibility` (~740), `recreateStatusItemsForVisibilityRecovery` (~720); the 4 disabled call sites.
- Subsystem git history: `6665d028 fix: repair hidden menu bar visibility defaults`, `e6d61a8d Harden menu bar status item placement`, `8545c76d fix: preserve menu bar placement on upgrade`, `55c0a105 fix: clear bad status item placement`.
