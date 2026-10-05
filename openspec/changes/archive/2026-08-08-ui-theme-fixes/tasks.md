# Tasks: UI Theme Fixes — Unified Orange Theme, Light Default, Splash Reliability, Navigation Access

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,220 (305 token usages + theme engine + splash + nav) |
| 400-line budget risk | Medium — PR #1 (~350) approaches budget; others ≤ 250 |
| Chained PRs recommended | Yes |
| Suggested split | 6 PRs per design D5 slicing table |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR / base |
|------|------|------------------|
| 1 | Theme engine: light default, persistence, role wiring, Settings toggle, login legibility | PR #1 / main |
| 2 | Splash: step isolation, 10s fail-open, fingerprint 3s non-fatal | PR #2 / PR #1 |
| 3 | Nav: `/workers` route+guard, menu items, home gradients+shortcut | PR #3 / PR #2 |
| 4 | Tokens: pos + products (10 files / 61 usages) | PR #4 / PR #3 |
| 5 | Tokens: license + sync (18 files / 120 usages) | PR #5 / PR #4 |
| 6 | Tokens: rest + delete legacy constants | PR #6 / PR #5 |

## Slice 1 — Theme engine (PR #1, ~350, base main)

- [x] 1.1 RED: `test/features/theme/theme_preferences_test.dart` — store round-trip (null→write→read) + `defaultThemeForRole` mapping (cocina→dark, others→light)
- [x] 1.2 GREEN: new `lib/config/theme/theme_preferences.dart` — `ThemePreferenceStore.read()/write()` (key `theme_mode`), `ThemePrefs.initialMode` static
- [x] 1.3 GREEN: `lib/config/theme/theme_provider.dart` — default `ThemeMode.light` (:11); system branch via `PlatformDispatcher.platformBrightness` (:26–35); `setDefaultThemeForRole` = saved ?? default (:66)
- [x] 1.4: `lib/main.dart` — seed `ThemePrefs.initialMode` from storage before `runApp()`
- [x] 1.5: `auth_provider.dart` login-success + splash session-active branch call `setDefaultThemeForRole` (verify role source — design open Q)
- [x] 1.6: `settings_screen.dart` (~116) — "Tema" `SegmentedButton<ThemeMode>` → provider + persist
- [x] 1.7 RED+GREEN: `login_screen.dart` — drop forced `Colors.white`/`grey.shade50`; widget test legible both modes (≥3:1)
- Verify: `flutter test`; `dart analyze`. Rollback: revert provider default to dark.

## Slice 2 — Splash bootstrap (PR #2, ~180, base PR #1)

- [x] 2.1 RED: `test/features/shared/splash_screen_test.dart` — never-completing fake step → `/login` at 10s; fingerprint throw non-fatal
- [x] 2.2 GREEN: `splash_screen.dart` — named step chain (db-init→plans-init→backup-init→exports-cleanup→users-query→license-read→license-validate→fingerprint→session-read→route), per-step try/catch + `[splash] STEP ok|fail` logs
- [x] 2.3: chain `.timeout(10s, _failOpen)`; `_failOpen` → `/register` if `hasUsers==false` else `/login`; named constant rollback flag
- [x] 2.4: `license_service.dart` (:394) `getDeviceFingerprint` `.timeout(3s)`, throw→null; mismatch revoke→login (existing :115–124)
- [x] 2.5: splash bg `AppTheme.colorCeleste` → `AppColors.accent`
- Verify: `flutter test`; `dart analyze`. Rollback: raise/disable timeout constant.

## Slice 3 — Navigation (PR #3, ~250, base PR #2)

- [x] 3.1 RED: `test/features/workers/workers_route_guard_test.dart` — non-admin → redirect `/`
- [x] 3.2 GREEN: `lib/config/router/app_router.dart` — `GoRoute('/workers')`; `_isAdminOrSuperAdmin()` (storage `user_role`); redirect after `/licenses` check
- [x] 3.3: `side_menu.dart` — `AppMenuItem(add_circle_outline, 'Nuevo Pedido', '/orders/new')` + `AppMenuItem(people_alt, 'Usuarios', '/workers')` into `_adminMenuItems`/`_superAdminMenuItems`
- [x] 3.4: `home_screen.dart` — gradients `[accent, accent(.8), colors.warning(.7)]` via `AppColors.forBrightness`; admin shortcut card → `/orders/new`; replace 18 `AppTheme.*`
- Verify: `flutter test`; grep `AppTheme\.` in `lib/features/home` = 0; `dart analyze`. Rollback: revert router redirect + menu entries.

## Slice 4 — Token batch pos+products (PR #4, ~120, base PR #3)

- [x] 4.1: pos 5 files (`pos_screen`, `invoice_screen`, `payment_screen`, `prefactura_screen`, `orders_history_screen`) — `colorCeleste`→`AppColors.accent`, `colorMorado`→accent/`colors.warning`; drop `app_theme.dart` imports
- [x] 4.2: products 5 files (`products_screen`, `product_form_screen`, `import_products_screen`, `categories_screen`, `category_form_screen`)
- Verify: grep `AppTheme\.` in `lib/features/pos` `lib/features/products` = 0; `flutter test`; `dart analyze`. Rollback: revert batch commit.

## Slice 5 — Token batch license+sync (PR #5, ~180, base PR #4)

- [x] 5.1: license 8 files (~50 usages: detail/expired/cliente/my_license/all_licenses/clientes/dashboard/plan_pricing/banner/licenses_admin)
- [x] 5.2: sync 10 files (~70 usages: recibir_despacho, rendicion, procesar_rendicion, despacho, mis_despachos, historial_ventas/despachos/rendiciones/transferencias, mis_rendiciones)
- Verify: grep = 0 per dir; `flutter test`; `dart analyze`. Rollback: revert batch commit.

## Slice 6 — Token batch rest + cleanup (PR #6, ~140, base PR #5)

- [x] 6.1: inventory (31), exports (5), help (8), reports (2), settings (6), workers (14), shared residual (splash, widgets), `login_screen_etecsa`
- [x] 6.2: delete `AppTheme` legacy constants from `lib/config/theme/app_theme.dart` (decide alias per design open Q); remove per-file imports
- Verify: grep `AppTheme\.` in `lib` excl. `app_theme.dart` = 0; full `flutter test` + `dart analyze`. Rollback: restore constants via revert.
