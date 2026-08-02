# CodexBar — project log

Cumulative work log for the personal CodexBar fork. Newest context at the top of each section.

## 1. Engagement at a glance

- Project: CodexBar — macOS menu-bar app showing Codex/Claude/other-provider usage stats.
- This checkout is a personal customized fork: `origin` = ApexAspire/CodexBar, `upstream` = steipete/CodexBar. Working branch `stacked-squash` (rebased onto upstream 0.35.1).
- Custom feature: stacked-text menu-bar mode showing session + weekly limits as two colored text lines (`S:`/`W:` via `StackedTextStatusView`).
- Build: full Xcode app + widget packaging is available locally with `CODEXBAR_SIGNING=adhoc Scripts/package_app.sh release`; `CODEXBAR_SKIP_WIDGET=1` remains the Command Line Tools fallback. Install by replacing `/Applications/CodexBar.app` and launching that exact bundle.

## 2. Current direction (2026-08-02)

Fork remains on `stacked-squash`, which contains current `upstream/main` plus the local stacked-text work. Kimi's dropdown deliberately remains `primary=Weekly` / `secondary=Rate Limit`; the labeled stacked view maps those semantic lanes back to `S=Rate Limit` / `W=Weekly`. Template provider icons drawn into the non-template stacked composite must be explicitly tinted with the appearance-aware label color. Claude's model-scoped Fable quota is decoded from the structured `limits[]` response and rendered only in the dropdown through the existing extra-rate-window path. Pending: finalize `stacked-squash` → fork `main` (needs authorised force-push), stable self-signed signing, optional upstream PR for stacked-text.

## 3. Decisions and rulings log

| Date | Topic | Decision (source) |
|------|-------|-------------------|
| 2026-08-02 | Claude Fable quota | Current `upstream/main` has Fable cost pricing but no Fable quota display. Decode Fable from the OAuth/web `limits[]` model-scoped weekly entry (`kind=weekly_scoped`, `scope.model.display_name`, `percent`, `resets_at`) into `extraRateWindows`; the generic menu-card path then shows it in the dropdown without adding it to the menu bar. (This session.) |
| 2026-08-02 | Kimi stacked display | Preserve Kimi's dropdown order (`primary=Weekly`, `secondary=Rate Limit`), but swap those positions at the labeled stacked-text boundary so `S` means the 5-hour rate limit and `W` means weekly. Explicitly tint provider template masks inside the non-template stacked composite; `isTemplate` alone only tints when a control renders the image. (This session.) |
| 2026-08-02 | Fork freshness | `stacked-squash` contains `upstream/main` at `ae7455ba`. Fork `origin/main` is an old divergent line; its memory-leak and fitting-height fixes are already present in current code through upstream equivalents, so do not merge or cherry-pick those six old-line commits. (This session.) |
| 2026-07-14 | Weekly-only usage display | Labeled surfaces (stacked `S:`/`W:` text) resolve windows by semantic lane, not position; unlabeled icon bars keep positional fill (deliberate UX call — lane-strict would render an empty main bar). (This session, after sibling-grep review.) |
| 2026-07-14 | Sibling-grep MEDIUM findings | `resolvedWindows`/`resolvedRemaining` positional flattening for unlabeled codex icon bars left as-is pending UX decision; 2 LOW findings (perplexity stacked ordering, positional naming) recorded, not fixed. (This session.) |
| 2026-07-14 | OAuth token handling | Rotated refresh tokens from diagnostic refreshes must be persisted back to `~/.codex/auth.json`; done with explicit user authorization after classifier block. (This session.) |
| 2026-06-16 | Menu-bar icon placement | Root cause was macOS System Settings "Allow in Menu Bar" toggle, not code. (Prior session.) |
| 2026-06-15 | Fork strategy | Rebase fork onto upstream/main as `stacked-squash` (5 commits); finalization to fork `main` deferred (force-push hook-blocked). (Prior session.) |

## 4. Deliverables and version history

- 2026-08-02 — `76d66c3e` fix: correct Kimi stacked semantics and Dark Mode mark; decode Claude Fable's scoped weekly limit into the dropdown. Pushed to `origin/stacked-squash`; full app + widget packaged, installed as `/Applications/CodexBar.app`, and verified to record `CodexGitCommit=76d66c3e` with Launch at Login retained.
- 2026-07-14 — `dcb47cb7` fix: keep weekly-only Codex usage off the stacked session line (lane-aware `IconRemainingResolver.resolvedStackedWindows`; regression test). `59fc41b9` chore: gitignore `.claude/`. Pushed to `origin/stacked-squash`; app rebuilt, installed, visually verified (`S:--` / `W:7%`).
- 2026-06-16 — `bb3e1cc1` menu-bar dark-mode text colour, stacked line order, Settings-window fixes.
- 2026-06-15 — `stacked-squash` branch: stacked-text feature squash + CLT build accommodations (`CODEXBAR_SKIP_WIDGET`, @Entry macro expansion) + Settings-on-reopen.

## 5. Adversarial review corrections

- 2026-08-02 — sibling-grep post-fix sweep: 0 HIGH, 1 MEDIUM (`quotaWarningFlashImage` has the same template-into-composite tint risk outside stacked mode), 1 LOW (other provider-specific stacked labels remain positional UX debt). Both left outside the scoped Kimi fix.
- 2026-07-14 — sibling-grep post-fix sweep: 0 HIGH, 2 MEDIUM (unlabeled icon bars still positional — deliberate), 2 LOW. Structural note: `codexVisibleWindows()` collapses lane-tagged projection output to an untagged array; candidate refactor to a lane-keyed struct if more labeled consumers appear.

## 6. Open items

- Finalize `stacked-squash` → fork `main` (requires explicit re-auth + `git push --force-with-lease`).
- Stable self-signed code signing (stop Bartender losing track across ad-hoc rebuilds).
- Watch for OpenAI restoring session limits (Reddit reports the removal is temporary) — no code change needed; verify `S:` line repopulates.
- Optional: offer stacked-text feature upstream as a clean PR off current `upstream/main`.
- UX decision on sibling-grep MEDIUMs: should unlabeled icon bars also become lane-strict for weekly-only accounts?
