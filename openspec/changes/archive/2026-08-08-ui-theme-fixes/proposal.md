# Proposal: UI Theme Fixes — Unified Orange Theme, Light Default, Splash Reliability, Navigation Access

## Intent

Four user-facing failures on a cyan/purple fork of the design system:
1. **Login letters invisible** — login renders on forced white bg (login_screen.dart:107) while inheriting dark-theme cream text; `themeModeProvider` hardcodes `dark` and `setDefaultThemeForRole()` is never called.
2. **Theme not unified** — 43 files / 305 usages of legacy `AppTheme` (cyan #00BCD4, purple #9C27B0) coexist with the new `HamburguesaThemeData` (accent achiote #D9531E). Side menu is orange, home/splash/login are not.
3. **Light theme unreachable** — `HamburguesaThemeData.light` exists but no persistence, no Settings toggle, no role default wiring.
4. **Splash hangs** — `_initApp()`/`_checkLicense()` chain hangs (platform channel + DB queries); catch never fires → infinite spinner.
5. **Admin can't reach core screens** — admin/super_admin side menu lacks "Nuevo Pedido"; `workers_screen.dart` exists but has no route and no menu entry.

## Scope

### In Scope
- Theme provider: default `ThemeMode.light` w/ role default (Cocina→dark per role-flows spec), persistence (secure storage), Settings toggle.
- Theme tokens: migrate AppTheme → `AppColors`/`HamburguesaThemeData` across **~43 files / 305 usages**, in feature batches.
- Login, splash, home (gradient/appbar), side menu (all roles), shared widgets.
- Splash: hard timeout w/ step logging; fail-open to login on timeout.
- Admin access: add "Nuevo Pedido" (`/orders/new`) + "Usuarios" (`/workers`) menu items for admin; router `/workers` registration; admin home shortcut.

### Out of Scope
- License salts/keys (PosJVL2024) re-keying.
- `pubspec.yaml` name/package changes; DB schema changes.
- SMS protocol, order flow logic, license validation logic changes.

## Capabilities

### New Capabilities
- `theme-preferences`: persistent light/dark preference + role-based default + Settings toggle.
- `app-bootstrap`: splash step logging + hard timeout + fail-open policy.

### Modified Capabilities
- `role-flows`: design tokens + theme-default requirements now apply app-wide (all screens use token palette); admin navigation adds Nuevo Pedido/Usuarios with role gating.

## Approach

1. **PR #1** — theme engine: provider default light, role default wiring, persistence, toggle, login+splash fixes.
2. **PR #2..N** — batch per feature (auth, home, pos, products, license, sync, reports): replace `AppTheme` refs → tokens; gradient→accent.
3. **PR N+1** — navigation: admin menu items, `/workers` route + guard.
4. Splash decisions: timeout ~10s, log each step, fail-open.

## Affected Areas

| Area | Impact |
|------|--------|
| `lib/config/theme/theme_provider.dart` | Modified — default light, role default wired |
| `lib/config/theme/app_colors.dart`, `hamburguesa_theme.dart` | Modified (light bg decision; see Risks) |
| `lib/features/auth/.../login_screen.dart` | Modified — token approach, no forced white |
| `lib/features/shared/.../splash_screen.dart` | Modified — timeout + fallback |
| `lib/features/home/.../home_screen.dart` | Modified — gradients, shortcut card |
| `lib/features/shared/widgets/side_menu.dart` | Modified — admin items |
| `lib/config/router/app_router.dart` | Modified — `/workers` |
| `workers_screen.dart` + ~40 files | Modified — token migration |

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Dark-mode regressions in `cocina` (dark per role spec) | Med | Role-specific default; keep dark, never force light there |
| Contrast regressions across 43 screens | Med | Batch per feature + manual PRD review |
| Light bg conflict: user wants bright white vs spec token `#F6ECDF` (Papel) | High (decision needed) | Resolve in sdd-spec as explicit requirement |
| Worker routing exposure if guard bypassed | Med | Router-level role redirect guard, not just menu hidden |
| Batch diff >400-line review budget | High | Chained PRs: one per feature batch |

## Rollback Plan

- Each batch = one PR; per-PR revert restores hybrid visuals.
- To fall back any profile/screen: revert `ThemeMode` default to dark, keep AppTheme alias.
- Splash timeout behind flag constant; disable to restore old behavior.

## Dependencies

- `flutter_color_themes` not needed. Requires `google_fonts`, `flutter_secure_storage` (already in pubspec).

## Success Criteria

- [ ] Login visible on light bg, high contrast (manual + widget test)
- [ ] 0 occurrences of `AppTheme.colorCeleste/colorMorado` in `lib/` (grep)
- [ ] Light theme persists after login across restarts; admin/redes default light, cocina dark
- [ ] Splash reaches login ≤30s even when device-fingerprint hangs (mock test)
- [ ] Admin/super_admin reach `/orders/new` and `/workers`; render robe verified for other roles
- [ ] `dart analyze` clean, `flutter test` green