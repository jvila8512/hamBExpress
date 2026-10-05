# Archive Report: 2026-08-08-ui-theme-fixes

**Archived**: 2026-08-11
**Source**: `openspec/changes/2026-08-08-ui-theme-fixes/`
**Destination**: `openspec/changes/archive/2026-08-08-ui-theme-fixes/`
**Status**: ✅ Complete — 6 slices implemented, verified PASS, ready for stacked PRs

---

## Summary

Fix 5 UI/UX problems in ExpresPOS: (1) invisible login on dark splash, (2) unify brand orange theme, (3) enable light theme by default, (4) splash stuck on loading, (5) admin access to "Nuevo Pedido"/"Usuarios". Delivered as 6 stacked PR slices + 2 post-verify fixes.

### Scope Delivered

- **Theme Engine (PR 1, `92aaaf0`)**: `ThemePreferenceStore` (key `theme_mode`), `theme_provider.dart` with `ThemeMode.light` default, system branch via `PlatformDispatcher`, role defaults (cocina→dark, others→light), `main()` seeds `initialMode` before `runApp`, Settings `SegmentedButton<ThemeMode>` persists, login drops forced white + legibility test (≥3:1)
- **Splash Bootstrap (PR 2, `c599a08`)**: named step chain with per-step try/catch + `[splash] STEP` logs, 10s fail-open timeout → `/register` (no users) or `/login`, fingerprint 3s non-fatal (throw→null), splash bg brand accent
- **Navigation (PR 3, `c5f9a00`)**: `/workers` GoRoute + `_isAdminOrSuperAdmin()` guard, side menu items (Nuevo Pedido → `/orders/new`, Usuarios → `/workers`), home gradients `[accent, accent(.8), warning(.7)]` + admin shortcut
- **Token Migration (PR 4–6, `5615dff`, `bb41865`, `c60a5a7`)**: all `AppTheme.colorCeleste`/`colorMorado` → `AppColors.accent`/`colors.warning` across 40 files; deleted legacy `lib/config/theme/app_theme.dart`; removed `config.dart` export + dead import in adjustments_history_screen
- **Post-verify fixes (`1348b70`, `f02bb25`)**: `_boundedRouteStep` 10s fence around every `_decideRoute()` await (users-query, license-read, license-validate, fingerprint, license-revoke, session-read, role-read); pure `resolveMode(saved, role)` with 5 direct unit tests

---

## Artifact Syncing

### Delta Specs → Main Specs

| Domain | Action | Details |
|--------|--------|---------|
| `theme-preferences` | **Created** | New main spec at `openspec/specs/theme-preferences/spec.md` — unified palette, light default, role defaults, persistence |
| `app-bootstrap` | **Created** | New main spec at `openspec/specs/app-bootstrap/spec.md` — splash step chain, 10s fail-open, fingerprint 3s non-fatal |
| `role-flows` | **Merged** | Updated `openspec/specs/role-flows/spec.md` — admin navigation, role-gated theme defaults (+52/-4 lines) |

### Existing Main Specs (unchanged — no delta to merge)

| Domain | Main Spec Path |
|--------|----------------|
| `auth` | `openspec/specs/auth/spec.md` |
| `products` | `openspec/specs/products/spec.md` |
| `client-management` | `openspec/specs/client-management/spec.md` |
| `daily-close` | `openspec/specs/daily-close/spec.md` |
| `order-management` | `openspec/specs/order-management/spec.md` |
| `sms-protocol` | `openspec/specs/sms-protocol/spec.md` |
| `trusted-contacts` | `openspec/specs/trusted-contacts/spec.md` |

---

## Task Completion

All 22 tasks (1.1–6.2) marked `[x]` in `tasks.md`. Verified by fresh re-run:

| Slice | Status | Evidence |
|-------|--------|----------|
| 1 Theme engine | ✅ | 13 theme_preferences tests + 4 login legibility tests |
| 2 Splash bootstrap | ✅ | 5 startup_flow + 4 splash tests (incl. 2 new route-fence timeout tests) |
| 3 Navigation | ✅ | 8 workers_route_guard tests |
| 4 Token batch pos+products | ✅ | grep `AppTheme\.` in lib = 0 |
| 5 Token batch license+sync | ✅ | grep `AppTheme\.` in lib = 0 |
| 6 Token batch rest + delete legacy | ✅ | `app_theme.dart` deleted; 0 refs |
| Post-verify fix splash fence | ✅ | `_boundedRouteStep` covers all 7 route awaits |
| Post-verify fix resolveMode | ✅ | 5 direct unit tests |

**Final verification (fresh re-run, topic `sdd/2026-08-08-ui-theme-fixes/verify-report` in engram)**: PASS — 144 tests green / 7 preexisting schema_v14 drift failures (baseline, untouched), `dart analyze` 0 errors / 302 baseline infos.

---

## Known Gaps

| Gap | Impact | Notes |
|-----|--------|-------|
| 7 preexisting `schema_v14` drift tests fail | Cosmetic for this change | Present before this change; `lib/core/database/` is out of scope, on do-not-touch list |
| `Future.timeout` doesn't cancel underlying hung future | Minor | After fail-open the abandoned step keeps running until it resolves; acceptable — splash already navigated away |
| `rules.archive` in `openspec/config.yaml` | Empty | No archive-specific rules defined (same as previous archive) |

---

## Archive Contents

| Artifact | Path |
|----------|------|
| proposal.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/proposal.md` |
| specs/theme-preferences/spec.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/specs/theme-preferences/spec.md` |
| specs/app-bootstrap/spec.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/specs/app-bootstrap/spec.md` |
| specs/role-flows/spec.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/specs/role-flows/spec.md` |
| design.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/design.md` |
| tasks.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/tasks.md` |
| archive-report.md | `openspec/changes/archive/2026-08-08-ui-theme-fixes/archive-report.md` |

---

## SDD Cycle Complete

The change `2026-08-08-ui-theme-fixes` has been fully planned, implemented (6 chained slices + 2 post-verify fixes on `feature/hamburguesa-express`, head `f02bb25`), verified (PASS), and archived. Pending only: create the 6 stacked PRs (stacked-to-main) and merge sequentially.
