# Design: UI Theme Fixes — Unified Orange Theme, Light Default, Splash Reliability, Navigation Access

## Technical Approach

Ship as **6 chained PRs** (guard ≤400 changed lines each): PR #1 theme engine `light` default + persistence (theme-preferences), #2 splash bootstrap (app-bootstrap), #3 `/workers` + side menu + home (role-flows), #4–#6 token migration in feature batches, final PR removes legacy constants. Each batch independently compilable + grep-verifiable.

## Architecture Decisions

### D1: Theme engine wiring

| Option | Tradeoff | Decision |
|---|---|---|
| Replace StateProvider with `NotifierProvider` | Modern, but churns existing `themeModeProvider.notifier` call sites and legacy imports | **Keep legacy `StateProvider<ThemeMode>`**, default flips `dark` → `light` (theme_provider.dart:11) |
| Read persisted mode via ProviderScope override in `main()` | Override API varies between riverpod 3.3 and legacy; fragile | **Seed a static before `runApp()`**: `ThemePrefs.initialMode` (set from secure storage in async `main`) read by the provider initializer — zero API churn |
| Persist per-user | Secure-storage key must track `user_id` | **Single key `theme_mode`** ('light'\|'dark'\|'system'); absence ⇒ role default. Matches spec (user choice overrides role default globally) |

- Store: `FlutterSecureStorage` key `theme_mode` (`light|dark|system`), read in async `main()` between `Environment.initEnvironment()` and `runApp()` (before first frame).
- `setDefaultThemeForRole(ref, role)` (dead, theme_provider.dart:66) becomes `state = saved ?? defaultThemeForRole(role)`; called from `AuthNotifier.loginUser` success branch (auth_provider.dart:59–62) and splash's session-active branch (cold-start `/`).
- Settings toggle: "Tema" section in `settings_screen.dart` (~line 116) with `SegmentedButton<ThemeMode>` (Claro/Oscuro/Sistema) → writes provider + persists; immediate via `ref.watch(themeModeProvider)` in `MainApp`.
- `currentThemeProvider` system branch (theme_provider.dart:26–35) must follow `PlatformDispatcher.instance.platformBrightness`, not hardcode dark.

### D2 — Token migration mapping (batch rule)

| Legacy | Replacement | Notes |
|---|---|---|
| `AppTheme.colorCeleste` | `AppColors.accent` | Brand primary everywhere; alpha variants → `accent.withValues(alpha: x)` |
| `AppTheme.colorMorado` | `AppColors.accent` (or `colors.warning` when used as 2nd gradient stop) | No purple token exists; single-accent brand |
| `AppTheme.scaffoldBackgroundColor` | remove prop / `Theme.of(ctx).scaffoldBackgroundColor` | Theme provides `colors.bg` already |
| `import app_theme.dart` | remove per file | grep-completeness per batch |

Home gradients (home_screen.dart:116–123) + role cards: `[accent, accent(0.8), colorMorado(0.6)]` → `[accent, accent(0.8), colors.warning(0.7)]`, resolved via `AppColors.forBrightness(Theme.of(context).brightness)` so dark→`warningDark`, light→`warningLight`; keep white foreground text (3:1 on accent). Login (login_screen.dart:107) drops `backgroundColor: Colors.white` and `fillColor: Colors.grey.shade50` on fields — the themed `InputDecorationTheme` (hamburguesa_theme.dart:165) already supplies correct per-mode fills.

### D3 — Splash bootstrap (app-bootstrap spec)

Restructure `_SplashScreenState` into a named ordered step list; each step wrapped in its own try/catch that logs `[splash] STEP name -> ok|fail` and continues:

```
db-init → plans-init → backup-init → exports-cleanup
→ users-query → license-read → license-validate
→ fingerprint → session-read → route
```

Wrap the chain: `.timeout(Duration(seconds: 10), onTimeout: _failOpen)`; `_failOpen()` logs last-completed step, routes `/register` if `hasUsers == false` else `/login`. `getDeviceFingerprint` (license_service.dart:394) gets its own `.timeout(Duration(seconds: 3))`; throw/timeout → `null` (non-fatal); mismatch → revoke `activated_license`/`license_key` + `/login` with message (existing lines 115–124, inside its own try/catch). Fallback order preserved: register → login/no-license → expired → invalid → mismatch → home<24h → login. Background `AppTheme.colorCeleste` → `AppColors.accent`. Timeouts are named constants (rollback flag).

### 4 — `/workers` route + guard (role-flows spec)

Register `GoRoute(path: '/workers', builder: ... WorkersScreen())`. Add `_isAdminOrSuperAdmin()` async helper (storage `user_role`) and, inside the existing `redirect` block, after the `/licenses` check: `if (currentPath == '/workers' && loggedIn && !admin) return '/'`. Menu: insert `AppMenuItem(add_circle_outline, 'Nuevo Pedido', '/orders/new')` + `AppMenuItem(people_alt, 'Usuarios', '/workers')` into `_adminMenuItems` and `_superAdminMenuItems` (side_menu.dart:70–96); home_screen gets an admin-only shortcut card → `/orders/new`.

### 5 — Slicing (~305 replacements)

| PR | Scope | Est. changed lines |
|---|---|---|
| #1 | Theme engine: provider default, persistence, `setDefaultThemeForRole` wiring, Settings toggle, login legibility | ~350 |
| #2 | Splash bootstrap redesign (app-bootstrap) | ~180 |
| #3 | Home gradients/cards + side menu (admin/super) + router `/workers` + home shortcut | ~250 |
| #4 | Token batch: pos (5 files/45) + products (5/16) | ~120 |
| #5 | Token batch: license (8/50) + sync (10/70) | ~180 |
| #6 | Token batch: inventory (31), exports (5), help (8), reports (2), settings (6), workers (14), shared/splash-residual; then delete legacy constants + imports | ~140 |

Each PR: `grep -rn "AppTheme\." lib --include=*.dart | grep -v app_theme.dart` = 0 for its files; `dart analyze` clean.

## Data Flow

```
main() ──secure storage──> ThemePrefs.initialMode
   │                              │
   ▼                              ▼
ProviderScope(themeModeProvider=light|saved) ──▶ MaterialApp.themeMode
AuthNotifier.loginUser ──▶ setDefaultThemeForRole(user.role)
   └── user saved choice? ─ no → defaultThemeForRole(role)   | Settings toggle ──▶ provider + storage
```
```
Splash ──10s fence──> steps[db,plans,backup,exports,users,license,fingerprint(3s),session] ──▶ route
   └── timeout/error ──▶ bool hasUsers? /register : /login
```

## Interfaces / Contracts

```dart
// lib/config/theme/theme_preferences.dart (new)
abstract final class ThemePreferenceStore {
  static const _key = 'theme_mode';
  static Future<ThemeMode?> read();            // null = no choice (use role default)
  static Future<void> write(ThemeMode mode);
}
abstract final class ThemePrefs {
  static ThemeMode? initialMode;                // seeded by main() before runApp
}
```
No DB schema changes; no license re-key.

## Testing Strategy

| Layer | What | How |
|---|---|---|
| Unit | defaultThemeForRole mapping; store round-trip | `flutter_test` (new `test/` dir) |
| Widget | Settings toggle persists; login legible both modes (no `Colors.white` forced) | flutter_test |
| Widget | Splash timed-out path routes to fallback via fake step that never completes; fingerprint throw non-fatal | `flutter test` with fake timers; assert lands on `/login` |
| Manual/grep | Batch migration; role gating `/workers` | grep=0 per batch; visual pass |

## Migration / Rollout

Splash timeout constant (named, default 10s) is the rollback flag: set huge/disable to restore legacy behavior. Per-PR revert restores hybrid visuals. `AppTheme` legacy constants deleted only in the final PR when grep proves 0 usages.

## Open Questions

- [ ] Mesero/vendedor role strings vs `user.roles` — first element reliable as primary role? (verify `AuthRepository.login` payload)
- [ ] Keep a `AppTheme.getTheme()` alias for the `test/` future, or hard-delete the class?