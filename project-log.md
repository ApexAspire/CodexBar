# CodexBar — project log

Cumulative work log for the personal CodexBar fork. Newest context at the top of each section.

## 1. Engagement at a glance

- Project: CodexBar — macOS menu-bar app showing Codex/Claude/other-provider usage stats.
- This checkout is a personal customized fork: `origin` = ApexAspire/CodexBar, `upstream` = steipete/CodexBar. Working branch `stacked-squash` (rebased onto upstream 0.35.1).
- Custom feature: stacked-text menu-bar mode showing session + weekly limits as two colored text lines (`S:`/`W:` via `StackedTextStatusView`).
- Build: Command Line Tools only (no full Xcode). `CODEXBAR_SIGNING=adhoc CODEXBAR_SKIP_WIDGET=1 Scripts/package_app.sh release`, then swap `/Applications/CodexBar.app`.

## 2. Current direction (2026-07-14)

Fork is stable on `stacked-squash` with the weekly-only display fix shipped and installed. OpenAI has (reportedly temporarily) removed session limits for this account's plan (`prolite`) — the app now renders `S:--` / `W:n%` and will self-restore the session line when the API brings the 5h window back. Pending: finalize `stacked-squash` → fork `main` (needs authorised force-push), stable self-signed signing, optional upstream PR for stacked-text.

## 3. Decisions and rulings log

| Date | Topic | Decision (source) |
|------|-------|-------------------|
| 2026-07-14 | Weekly-only usage display | Labeled surfaces (stacked `S:`/`W:` text) resolve windows by semantic lane, not position; unlabeled icon bars keep positional fill (deliberate UX call — lane-strict would render an empty main bar). (This session, after sibling-grep review.) |
| 2026-07-14 | Sibling-grep MEDIUM findings | `resolvedWindows`/`resolvedRemaining` positional flattening for unlabeled codex icon bars left as-is pending UX decision; 2 LOW findings (perplexity stacked ordering, positional naming) recorded, not fixed. (This session.) |
| 2026-07-14 | OAuth token handling | Rotated refresh tokens from diagnostic refreshes must be persisted back to `~/.codex/auth.json`; done with explicit user authorization after classifier block. (This session.) |
| 2026-06-16 | Menu-bar icon placement | Root cause was macOS System Settings "Allow in Menu Bar" toggle, not code. (Prior session.) |
| 2026-06-15 | Fork strategy | Rebase fork onto upstream/main as `stacked-squash` (5 commits); finalization to fork `main` deferred (force-push hook-blocked). (Prior session.) |

## 4. Deliverables and version history

- 2026-07-14 — `dcb47cb7` fix: keep weekly-only Codex usage off the stacked session line (lane-aware `IconRemainingResolver.resolvedStackedWindows`; regression test). `59fc41b9` chore: gitignore `.claude/`. Pushed to `origin/stacked-squash`; app rebuilt, installed, visually verified (`S:--` / `W:7%`).
- 2026-06-16 — `bb3e1cc1` menu-bar dark-mode text colour, stacked line order, Settings-window fixes.
- 2026-06-15 — `stacked-squash` branch: stacked-text feature squash + CLT build accommodations (`CODEXBAR_SKIP_WIDGET`, @Entry macro expansion) + Settings-on-reopen.

## 5. Adversarial review corrections

- 2026-07-14 — sibling-grep post-fix sweep: 0 HIGH, 2 MEDIUM (unlabeled icon bars still positional — deliberate), 2 LOW. Structural note: `codexVisibleWindows()` collapses lane-tagged projection output to an untagged array; candidate refactor to a lane-keyed struct if more labeled consumers appear.

## 6. Open items

- Finalize `stacked-squash` → fork `main` (requires explicit re-auth + `git push --force-with-lease`).
- Stable self-signed code signing (stop Bartender losing track across ad-hoc rebuilds).
- Watch for OpenAI restoring session limits (Reddit reports the removal is temporary) — no code change needed; verify `S:` line repopulates.
- Optional: offer stacked-text feature upstream as a clean PR off current `upstream/main`.
- UX decision on sibling-grep MEDIUMs: should unlabeled icon bars also become lane-strict for weekly-only accounts?
