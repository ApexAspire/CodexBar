# CodexBar — project log

Cumulative work log for the personal CodexBar fork. Newest context at the top of each section.

## 1. Engagement at a glance

- Project: CodexBar — macOS menu-bar app showing Codex/Claude/other-provider usage stats.
- This checkout is a personal customized fork: `origin` = ApexAspire/CodexBar, `upstream` = steipete/CodexBar. Working branch `stacked-squash` (rebased onto upstream 0.35.1).
- Custom feature: stacked-text menu-bar mode showing session + weekly limits as two colored text lines (`S:`/`W:` via `StackedTextStatusView`).
- Build: full Xcode app + widget packaging is available locally with `CODEXBAR_SIGNING=adhoc Scripts/package_app.sh release`; `CODEXBAR_SKIP_WIDGET=1` remains the Command Line Tools fallback. A cold Xcode widget build can exceed the script's 900-second default while still compiling normally; after confirming active compiler work and no build error, use the supported `CODEXBAR_WIDGET_EXTENSION_TIMEOUT_SECONDS=2400` override. Install by replacing `/Applications/CodexBar.app` and launching that exact bundle.

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

- 2026-08-30 — `f6509944c` fix(deepseek): unknown usage-category keys count toward token/spend sums (`.unknown` passthrough) instead of silently zeroing them — sibling-grep HIGH finding under the DeepSeek spend tile. `cbe54fb3b` fix(perplexity): unknown grant types pool with purchased credits (respecting past expiry) instead of dropping and rendering fake "0/0 credits, 100% used" — sibling-grep HIGH finding. `465c381e0` fix(zai): stacked `S:`/`W:` resolved positionally — S showed weekly, W showed nothing; now maps session=tertiary (5-hour), weekly=primary, like the Kimi branch. `56ec81cfc` feat(kimi,zai): weekly pace projection (expected-vs-actual, run-out ETA) now renders for Kimi and ZAI — pace consumers had hardcoded weekly=secondary, but these providers keep weekly in primary on this fork; new `IconRemainingResolver.weeklyPaceWindow` owns the lane, and Kimi's weekly window now carries 10080 minutes so the generic pace path accepts it.
- 2026-08-30 — `cccef3455` fix(zai): parse CREDIT_LIMIT quota entries; restore 5-hour/weekly limits. GLM Coding Plans renamed TOKENS_LIMIT → CREDIT_LIMIT; the parser dropped both coding windows. Port of upstream `013680770` (+ `level` plan key from `7002b5782`, usedPercent clamp from `39d86dae2`) adapted to the fork lane layout; upstream's lane reorder, JS cutover, and declarative details deliberately NOT taken. Full suite green; live-verified via installed-bundle CLI (weekly 98% left / 6d22h, 5-hour 88% left / 3h49m, Plan: Pro). Replaced `/Applications/CodexBar.app` (was `dc5893f7`), Launch at Login retained.
- 2026-08-02 — `76d66c3e` fix: correct Kimi stacked semantics and Dark Mode mark; decode Claude Fable's scoped weekly limit into the dropdown. Pushed to `origin/stacked-squash`; full app + widget packaged, installed as `/Applications/CodexBar.app`, and verified to record `CodexGitCommit=76d66c3e` with Launch at Login retained.
- 2026-07-14 — `dcb47cb7` fix: keep weekly-only Codex usage off the stacked session line (lane-aware `IconRemainingResolver.resolvedStackedWindows`; regression test). `59fc41b9` chore: gitignore `.claude/`. Pushed to `origin/stacked-squash`; app rebuilt, installed, visually verified (`S:--` / `W:7%`).
- 2026-06-16 — `bb3e1cc1` menu-bar dark-mode text colour, stacked line order, Settings-window fixes.
- 2026-06-15 — `stacked-squash` branch: stacked-text feature squash + CLT build accommodations (`CODEXBAR_SKIP_WIDGET`, @Entry macro expansion) + Settings-on-reopen.

## 5. Adversarial review corrections

- 2026-08-02 — sibling-grep post-fix sweep: 0 HIGH, 1 MEDIUM (`quotaWarningFlashImage` has the same template-into-composite tint risk outside stacked mode), 1 LOW (other provider-specific stacked labels remain positional UX debt). Both left outside the scoped Kimi fix.
- 2026-07-14 — sibling-grep post-fix sweep: 0 HIGH, 2 MEDIUM (unlabeled icon bars still positional — deliberate), 2 LOW. Structural note: `codexVisibleWindows()` collapses lane-tagged projection output to an untagged array; candidate refactor to a lane-keyed struct if more labeled consumers appear.

## 6. Open items

- Sibling-sweep findings from the CREDIT_LIMIT fix (2026-08-30): both HIGH findings FIXED same day (`f6509944c` DeepSeek unknown categories, `cbe54fb3b` Perplexity grant pooling). Still unfixed: **MEDIUM** ZaiUsageStats.swift:278 — unknown future limit types still drop silently, no log; Codebuff/Mistral fetchers — wholesale key rename yields silent-empty display (copy Alibaba's throw-on-no-data pattern). 5 LOW (Kimi scope string, Antigravity oneof, Gemini tier, MiniMax lane, Claude web window keys). Fix individually, each verified against its own fixture.
- Rich-info parity for Kimi/ZAI (user request 2026-08-30): weekly pace projection DELIVERED (`56ec81cfc`). Remaining gap: **(a)** 5-hour session-lane projection (`UsagePaceText.sessionPace` allowlists only codex/claude/ollama; Kimi's secondary and ZAI's tertiary are 5-hour windows with no pace render site); **(b)** API-equivalent token cost over 30 days — needs a token-usage source Kimi/ZAI don't have wired (Claude/Codex/Mistral use local session logs + `supportsTokenCost` descriptors; upstream's ZAI/Kimi equivalents shipped via the JS-plugin + declarative-details architecture this fork deliberately excluded). Research data availability (GLM monitor usage endpoints, Moonshot platform API, local `kimi` CLI logs) before scoping.
- Finalize `stacked-squash` → fork `main` (requires explicit re-auth + `git push --force-with-lease`).
- Stable self-signed code signing (stop Bartender losing track across ad-hoc rebuilds).
- Watch for OpenAI restoring session limits (Reddit reports the removal is temporary) — no code change needed; verify `S:` line repopulates.
- Optional: offer stacked-text feature upstream as a clean PR off current `upstream/main`.
- UX decision on sibling-grep MEDIUMs: should unlabeled icon bars also become lane-strict for weekly-only accounts?
