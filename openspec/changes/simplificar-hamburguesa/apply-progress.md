# Apply Progress — simplificar-hamburguesa

Units: Phase 1 (Schema v16, branch `pr/11-schema-v16`) · Phase 2 (Orders Core 2.1–2.5, branch `pr/12-orders-core`) · Phase 3 (Row Actions 3.1–3.2, branch `pr/13-row-actions`) · Phase 4 (Deletions 4.1–4.3, branch `pr/14-deletions`) · Phase 5 (Roles/Guard/Menus 5.1–5.2, branch `pr/15-roles-guard`) · Phase 5 follow-up (legacy-role residuals A–D, branch `pr/15-roles-guard`)
Mode: strict TDD · Last updated: 2026-10-06

## Status

| Phase | Tasks | State |
|---|---|---|
| 1. Schema v16 | 1.1–1.3 | ✅ Done (commits on `pr/11-schema-v16`) |
| 2. Orders core | 2.1–2.5 | ✅ Done (commits below) |
| 3. Row actions | 3.1–3.2 | ✅ Done (commits below) |
| 4. Deletions | 4.1–4.3 | ✅ Done (commits below) |
| 5. Roles, guard, menus | 5.1–5.2 | ✅ Done (commits on `pr/15-roles-guard`) |
| 5b. Legacy-role residuals (A–D) | follow-up | ✅ Done (commits below) |
| 6. Days + close | 6.1–6.3 | ⬜ Pending |
| 7. Forms + catalog | 7.1–7.2 | ⬜ Pending |
| 8. Final verification | 8.1 | ⬜ Pending (analyzers/targets below) |

## Phase 1 — completed work

- **Schema v16** (`lib/core/database/app_database.dart`): `schemaVersion => 16`,
  `RestaurantOrders.fecha_pedido`, `DailySummaries.topClientesJson`,
  7 dead restaurant tables undeclared + dropped (`TrustedContacts`, `SmsMessages`,
  `RestaurantTables`, `OrderStateHistory`, `DailyExpenses`, `DailyPurchases`,
  `DailyPayroll`), POS order tables dropped, legacy orders truncated, role remap
  CASE (8 legacy roles → `{admin, vendedor}`) + admin seed on empty Users table.
  Migration logs use `debugPrint` (project convention, avoids `avoid_print`).
- **Codegen**: `lib/core/database/app_database.g.dart` regenerated
  (`dart run build_runner build`, 385s, source_gen 4.2.4) — exists and compiles.
- **De-dangling** (only files that failed to compile; screens untouched):
  - `contacts/infrastructure/datasources/contact_datasource.dart` → v16 stub
    (reads → `null`/`const []`, writes → no-op; table dropped per spec).
  - `contacts/presentation/providers/contact_provider.dart` and
    `contacts/presentation/screens/trusted_contacts_screen.dart` → removed
    `hide TrustedContact` from the app_database import.
  - `daily_close/presentation/providers/daily_close_provider.dart` → bridge DTOs
    (`DailyExpense`, `DailyPurchase`, `DailyPayrollData`, `OrderStateHistoryData`)
    + stubbed helpers/CRUD (spec removes daily-close manual blocks).
  - `daily_close/presentation/screens/daily_close_screen.dart` → NOT modified;
    compiles against provider DTOs.
- **Tests**: `test/architecture/license_strip_guard_test.dart` assertion bumped
  `schemaVersion => 15` → `16` (same commit as the bump it verifies).
  `test/core/database/schema_v14_test.dart` + `schema_v14_additional_tables_test.dart`
  rewritten in commit `9035d42` (RED) — now GREEN.

## Phase 1 — evidence

- Baseline (pre-unit): **210 pass / 7 fail** — all 7 failures were the two schema
  test files (4 + 3).
- `dart analyze lib test`: **0 errors, 47 warnings, 86 infos** (133 issues).
  Targets (tasks Phase 8): 0 errors / ≤48 warnings / ≤86 infos — all met.
  Design target ≤47 warnings also met. The 86 infos are pre-existing except none
  added by this unit (the 2 new migration logs are `debugPrint`).
- `flutter test test/core/database`: **7/7 passed** (was 7 failing at baseline).
- Targeted re-check of the two tests importing `contact_provider`
  (`order_notifier_sms_persist_test`, `order_notifier_resend_sms_test`): **19/19 passed**.
- Predicted full-suite baseline reconciliation: 210 + 7 = **217 pass / 0 fail**
  (full suite intentionally not run in this unit; verify phase confirms).

## Phase 2 — completed work (2.1–2.5)

- **2.1/2.2 — three-state machine** (`order_state.dart`, `restaurant_order.dart`):
  `OrderState {pedido, confirmado, recogido}` + `canTransitionTo` (no skips, no
  backwards, no self-loops, `recogido` terminal, unknown/legacy `estado` reads as
  `pedido`); `RestaurantOrder.fechaPedido` added, SMS/legacy fields
  (`tipoPedido`, `mesaId`, `metodoPago`, `motivoCancelacion`, `sms*`,
  `canalOrigen`, `horaSolicitada`) dropped.
- **2.3 — order id builder** (`order_id.dart` `buildOrderId`): `A`/`V` origin
  prefix, `originSeq = 1`, day-sequential daily seq.
- **2.4/2.5 — validated transitions + day field (this unit)**:
  - `OrderDatasource.updateOrderState` now reads the row, validates via
    `canTransitionTo`, throws `StateError` on invalid/unknown order **before any
    write** (stored `estado` untouched), writes only on a legal move.
  - Day reads: `getOrdersByDay(fechaIso)` filters `fechaPedido == yyyy-MM-dd`;
    `getTodayOrders()` delegates to it (pure `_todayIso()` helper replaces the
    old `fechaCreacion >= startOfDay` filter).
  - `OrderRepository`/`OrderRepositoryImpl`: `getOrdersByDay` added;
    `markSmsStatus` + `markSmsConfirmado` removed (SMS ACK persistence is Phase 4
    deletion territory; `order_provider.dart` no longer calls them).
  - `lib/core/database/app_database.dart` +4: `AppDatabase.forTesting(super.executor)`
    constructor so tests can inject an executor with the real migration strategy.
  - Test updates: fakes implement `getOrdersByDay` and drop the `markSms*`
    overrides; datasource test asserts `getAllOrders()` estado after a rejected
    transition; `order_notifier_sms_persist_test.dart` −139 lines — file KEPT
    (not vacuous: 4 real tests remain — pure `isSmsPendingState` for 3 states +
    `loadTodayOrders` rehydration pending/not-pending).

## Phase 2 — evidence

- `dart analyze lib test`: **0 errors, 47 warnings, 86 infos** (133 issues).
  Gate: 0 errors / ≤47 warnings / ≤86 infos — all met, no new diagnostics.
- `flutter test test/features/orders`: **50 passed / 0 failed**
  (`+50: All tests passed!`) — includes all 2.4 RED cases now GREEN.
- Codegen: `dart run build_runner build --build-filter=lib/core/database/app_database.g.dart`
  (353s, source_gen 4.2.4) → `lib/core/database/app_database.g.dart` regenerated
  **byte-identical** (the `forTesting` constructor does not affect drift output);
  `.g.dart` exists, tracked, unchanged in git. No generated file was deleted.
- Full suite NOT run in this unit (Phase 8 / orchestrator limit).

## Phase 3 — completed work (3.1–3.2)

- **3.1 RED** — `test/features/orders/presentation/widgets/order_row_actions_test.dart`
  (4 widget tests): `pedido` → visible label `Confirmar` + tap advances to
  `confirmado`; `confirmado` → `Marcar recogido` + tap advances to `recogido`;
  `recogido` → label `Recogido`, tap invokes **inspect only** (asserts
  `onAdvance` never fired — terminal = no transition action); plus one test
  asserting the row exposes exactly the three spec actions (SMS / call / state).
  RED was a compile failure (`order_row_actions.dart` not found,
  `OrderRowActions` method not found), commit `3aee121`.
- **3.2 GREEN** — `lib/features/orders/presentation/widgets/order_row_actions.dart`:
  pure `orderStateActionLabel(OrderState)` (`Confirmar` / `Marcar recogido` /
  `Recogido`), `nextOrderState(OrderState)` (`null` on terminal), URI builders
  `buildSmsUri(cell, body)` → `sms:<cell>?body=<resumen>` and
  `buildTelUri(cell)` → `tel:<cell>`; widget `OrderRowActions` renders the three
  actions, disables SMS/call when `clientCell` is empty and delegates the
  state button to `onAdvance(next)` / `onInspect()`. Intent launching is
  injectable (`launchExternal`, default `launchUrl`).
- **Wiring** — `order_history_screen.dart`: `OrderRowActions` appended to each
  ticket card; `_loadClientCells()` resolves `clienteId → telefono` via
  `clientRepositoryProvider.getAllClients()` (best-effort: on failure the map
  stays empty and SMS/call disable instead of breaking the list);
  `_advanceState(order, next)` calls `repo.updateOrderState` then reloads the
  list, surfacing a SnackBar on rejection. **No other feature's handlers were
  removed** — the screen had no per-row actions before this unit, so no
  cancel/notify/delete flow was orphaned (0 analyzer errors, no out-of-scope
  file touched).

## Phase 3 — evidence

- **Safety net (pre-modification)**: `dart analyze lib test` = **0 errors,
  47 warnings, 86 infos (133)** — identical to the recorded Phase 1/2 baseline;
  `flutter test test/features/orders` = **50 passed / 0 failed**.
- `dart analyze lib test` after the unit: **0 errors, 47 warnings, 86 infos
  (133 issues)** — caps (0 / ≤47 / ≤86) met with **zero new diagnostics**.
- `flutter test test/features/orders` after the unit: **54 passed / 0 failed**
  (50 baseline + 4 new).
- Full suite NOT run (Phase 8); `flutter build` NOT run (CDN geo-blocked).
- `.g.dart`: untouched — `lib/core/database/app_database.g.dart` exists, tracked,
  unchanged (`app_database.dart` was not modified, so no build_runner run).
- Test-file naming deviation: task 3.1 names `state_action_labels_test.dart`;
  the work-unit contract for this batch specified
  `test/features/orders/presentation/widgets/order_row_actions_test.dart`
  (same 4 assertions, colocated with the widget) — used the contract path.
- Label source: spec + design + proposal + tasks all say **`Confirmar`** for
  `pedido` (the launch prompt's paraphrase "Confirmar pedido" appears in no
  artifact); implemented `Confirmar` per spec Order Row Actions.
- Terminal-state copy: spec mandates the button label `Recogido` for the
  terminal state; "no transition action" is enforced behaviorally (tap →
  inspect, `onAdvance` never invoked).
- Proposal's "advance/inspect sheet" is NOT implemented — design.md (authoritative)
  specifies the label mapping and `OrderRowActions → updateOrderState` flow
  without a sheet, and the spec requirement says tapping advances directly.

## Phase 4 — completed work (4.1–4.3)

- **4.1 Deletions — 33 lib files** (`git rm`/worktree deletions, all explicit):
  - `features/sms/**` (7): `sms.dart`, `domain/domain.dart`,
    `domain/entities/sms_payload.dart`, `domain/services/sms_parser.dart`,
    `infrastructure/infrastructure.dart`,
    `infrastructure/services/{broadcast_receiver,sms_service}.dart`.
  - `features/contacts/**` (10): `contacts.dart`, `domain/{domain,entities/trusted_contact,repositories/contact_repository}.dart`,
    `infrastructure/{infrastructure,datasources/contact_datasource,repositories/contact_repository_impl}.dart`,
    `presentation/{providers/providers,providers/contact_provider,screens/trusted_contacts_screen}.dart`.
  - `features/exports/**` (4), `features/help/**` (1),
    `features/expenses/presentation/screens/{expenses,expense_form}_screen.dart` (2).
  - Products catalog: `categories_screen.dart`, `category_form_screen.dart`,
    `import_products_screen.dart`, `categories_provider.dart` (4).
  - Orders: `kitchen_queue_screen.dart`, `delivery_list_screen.dart`,
    `order_tracking_screen.dart` (3).
  - `config/theme/widgets/order_timer.dart`, `shared/widgets/export_options_dialog.dart`.
  - **Count reconciliation**: tasks.md said **32**; actual is **33**. The
    `{sms,contacts,exports,help}` group is **22** files, not 21 (the task text
    undercounted one barrel file). `features/expenses/**` really is 2 (only the
    two screens existed). No stray file was deleted beyond the listed scope.
- **4.2 Reference cleanup — 11 modified files** (surgical: dead imports,
  dead routes, dead widgets/lines only):
  - `lib/main.dart` — dropped `broadcast_receiver`/`sms_service`/
    `telephony_sdt` imports, the `_initSmsReceiver()` call and its function.
  - `lib/config/router/app_router.dart` — 9 dead `GoRoute`s removed
    (`/products/import`, `/categories`, `/categories/new`,
    `/categories/edit/:id`, `/expenses`, `/orders/tracking`, `/kitchen`,
    `/delivery`, `/contacts`, `/exports`, `/help`) + their screen imports;
    14 routes remain.
  - `lib/features/orders/presentation/providers/order_provider.dart` —
    `smsServiceProvider`, `SmsPayload`/`SmsService` imports, `resendSms`,
    `isSmsPending`/`smsPendingStates`/`isSmsPendingState`, `_smsPendingIds`,
    the PED/HEC/ENT send blocks; `createOrder` → `Future<void>`
    (`destinationPhone` dropped), `updateState` signature narrowed.
  - `lib/features/orders/presentation/screens/order_form_screen.dart` —
    kitchen-phone lookup, SMS snackbars, `_smsPending`, category tabs/grouping.
  - `lib/features/home/presentation/screens/home_screen.dart` — links to
    `/orders/tracking`, `/contacts` (×3), `/kitchen`, `/delivery`, `/exports`,
    `/expenses`.
  - `lib/features/products/.../{products_screen,product_form_screen}.dart` —
    `categories_provider` import + category dropdown/filter,
    `ExportOptionsDialog` → SnackBar.
  - `lib/features/shared/widgets/widgets.dart` — barrel entry
    `export_options_dialog.dart`.
  - `pubspec.yaml` — `telephony_sdt: ^0.2.3` (+ its comment) removed;
    `pubspec.lock` regenerated earlier by `flutter pub get` (0 `telephony`
    entries) — **no `flutter pub get` was re-run this unit (pubspec.yaml was
    not changed by this executor)**.
  - `android/app/src/main/AndroidManifest.xml` — `SEND_SMS`, `RECEIVE_SMS`,
    `READ_SMS` permissions and the `IncomingSmsReceiver` `<receiver>` block
    removed; re-read after edit, XML well-formed (root `<manifest>`).
  - `side_menu.dart` needed no edit: it never referenced a deleted route
    (only `/workers` and `/settings` survive).
- **4.3 Tests**: 5 test files deleted (53 tests) —
  `test/features/sms/{domain/services/{sms_parser,sms_serializer},
  infrastructure/services/sms_service}_test.dart`,
  `order_notifier_{resend_sms,sms_persist}_test.dart`;
  `restaurant_order_sms_test` **does not exist** in the repo (stale task text).
  `order_notifier_create_order_test.dart` fixed: `_FakeSmsService` removed,
  3 tests re-pinned to the SMS-free contract (save+prepend / list order /
  error rethrow + `isLoading`).
  `license_strip_guard_test.dart` needed **no edit** — the RED committed at
  `8a960c3` turns GREEN purely through the 4.1/4.2 source removals.
- **Hazard check**: nothing imports the deleted `features/contacts/` — the
  Phase-1 bridge stubs in `lib/features/daily_close/` were left untouched
  (they reference dropped drift tables, not the contacts feature).

## Phase 4 — evidence

- `dart analyze lib test` (final, committed tree): **0 errors, 37 warnings,
  74 infos (111 issues)**. Gates: 0 errors ✅ / ≤47 warnings ✅ (37) /
  ≤86 infos ✅ (74) — the deletions REMOVED 10 warnings and 12 infos vs the
  recorded 47/86 baseline; no new diagnostic introduced.
- Full suite `flutter test` (final): **138 passed / 0 failed**
  (`+138: All tests passed!`, exit 0).
- **Test-count reconciliation**: measured baseline **191** → now **138**;
  delta **−53** = exactly the `test(`+`testWidgets(` count of the 5 test files
  deleted in 4.3 (7 + 4 + 23 + 9 + 10 = 53). Static count at `8a960c3` = 189
  (+2 dynamically generated elsewhere) = 191; 191 − 53 = 138. **Zero tests lost
  beyond the subjects deleted by 4.1.**
- RED→GREEN proof for `8a960c3` was executed in an isolated worktree at
  `9275ae0` (commit 1, source deletions not yet applied): **136 passed,
  2 failed** — precisely the two Phase-4 guard assertions
  ("drops the SMS receiver", "help screen is gone"), 0 compile errors. Commit 2
  flips those to GREEN (verified by the final 138/138 run).
- `flutter pub get` was **not** needed this unit (no `pubspec.yaml` change by
  this executor); the pre-existing lock update stands and the scratch worktree
  run also resolved `Got dependencies!` cleanly.
- Zero-reference greps over `lib` + `test` (`git grep -I -E`): `sms-protocol`
  **0**, `trusted-contacts` **0**, `SmsService` **0**, each removed route
  (`/products/import`, `/categories*`, `/expenses`, `/orders/tracking`,
  `/kitchen`, `/delivery`, `/contacts`, `/exports`, `/help`) **0**;
  `telephony_sdt` **2** — both inside `license_strip_guard_test.dart` as
  intentional negative assertions, **0** in `pubspec.yaml`/`pubspec.lock`.
  `SEND_SMS|RECEIVE_SMS|READ_SMS|SMS_RECEIVED` appear only in `docs/` PRDs and
  the archived `2026-07-14-hamburguesa-express-mvp` change (audit trail,
  never edited).
- `.g.dart`: `lib/core/database/app_database.g.dart` exists, tracked,
  untouched by this phase (confirmed in the scratch worktree checkout too).
- `flutter build` NOT run (CDN geo-blocked). No branch created/pushed;
  no `5730bba1`/`6dc69496`/`9b973616` staged.


## Phase 5 — completed work (5.1–5.2)

- **5.1 RED — 5 test files, commit `7478531`** (safety net first: the 4 pre-existing
  files ran **66/66 green** before any edit):
  - `test/features/auth/role_mapping_test.dart` — rewritten to the **8 legacy DB
    values → 2 roles** mapping via `mapLegacyRoleToAppRole` (the CASE in the
    doc comment mirrors `_remapRolesToTwoRoles` line by line, ELSE included),
    plus `UserRole.values == [admin, vendedor]`, `isAdmin`/`isVendedor`
    getters, a legacy-string negative case, and the phone group preserved.
  - `test/config/router/route_guard_test.dart` — **NEW**, 23 cases covering
    `routeGuardDecision`: admin-only `/workers`, `/settings`,
    `/products`, `/products/new`, `/products/edit/:id` (admin → null,
    vendedor → `/`, `super_admin` legacy value → `/`), unauthenticated admin
    path → `/login`, shared `/orders/history`, `/orders/new`, `/clients`,
    `/days` open to both roles, public `/login|/register|/splash` never guarded.
  - `test/features/workers/workers_route_guard_test.dart` — same 8 cases,
    ported from `workersRedirectDecision(loggedIn:)` to
    `routeGuardDecision(authenticated:)`; `super_admin` flipped from allow →
    redirect `/` (the role no longer exists).
  - `test/features/theme/theme_preferences_test.dart` — theme-preferences delta:
    2-entry light matrix, "no legacy role defaults dark", resolveMode override
    cases; store round-trip group untouched.
  - `test/architecture/license_strip_guard_test.dart` — **forced update (see
    evidence)**: T5's "one list, two entries for every role" pin contradicts
    the role-flows delta; repinned to admin 2 + vendedor 3 entries and no
    legacy role labels.
- **5.2 GREEN — 7 lib files, commit `7274b18`**:
  - `user.dart`: `enum UserRole { admin, vendedor }`; getters reduced to
    `isAdmin` / `isVendedor` (SMS-era getters `isRedes/isCocina/isDomicilio/
    isMesero` deleted).
  - `auth_datasource_impl.dart`: `mapPosRoleToSmsRole` →
    `mapLegacyRoleToAppRole` (8-value switch + ELSE → `vendedor`, identical to
    the v16 CASE); register's first-user role `super_admin` → `admin` (the
    2-role set forbids creating `super_admin`, and a stored `super_admin`
    would now be locked out of `/workers` by the guard).
  - `app_router.dart`: `workersRedirectDecision` **replaced** by
    `routeGuardDecision(currentPath:, role:, authenticated:)` over the
    admin-only path set; redirect block calls it for every non-public path.
  - `side_menu.dart`: `_adminMenuItems` [Usuarios→`/workers`,
    Configuración→`/settings`] + `_vendedorMenuItems` [Pedidos→`/orders/history`,
    Clientes→`/clients`, Días→`/days`]; `_roleTitle` reduced to
    ADMINISTRADOR/VENDEDOR/MENÚ (legacy role labels deleted); unknown role →
    vendedor menu (least privilege).
  - `home_screen.dart`: 2 dashboards — admin (existing, keeps `Nuevo Pedido` +
    `Cierre del Día`) and new `Nuevo Pedido`-first `vendedor` dashboard with
    Pedidos Hoy/Pendientes stats and Clientes/Días quick links; the
    redes/cocina/domicilio/mesero dashboards (~150 lines) deleted; unknown
    role → vendedor dashboard (least privilege).
  - `theme_provider.dart`: `_roleThemeDefaults` = exactly 2 entries
    `{admin: light, vendedor: light}`, fallback light; no `dark` on any role
    default (dark only via saved user choice).
  - `status_badge.dart`: fixed 3-hex palette per role-flows —
    `pedido`→Achiote `#D9531E` (AppColors.accent), `confirmado`→Mostaza
    `#E4A22E` (warningDark), `recogido`→Mojo `#7C9A3B` (successDark), both
    themes (swaps the previous pedido/confirmado accent-warning pairing).

## Phase 5 — evidence

- **Safety net (pre-modification)**: the 4 existing target files ran
  **66/66 passed** (16 role_mapping + 8 workers guard + 18 theme + 24 license
  guard) on `def0633`.
- **RED (commit `7478531`, real captured output)**:
  - `role_mapping_test.dart` → compile RED, `Method not found:
    'mapLegacyRoleToAppRole'` ×10 + `The getter 'isVendedor' isn't defined
    for the type 'User'` ×4, `Some tests failed.` exit 1.
  - `route_guard_test.dart` → compile RED, `Method not found:
    'routeGuardDecision'` ×23 sites, `Some tests failed.` exit 1.
  - `workers_route_guard_test.dart` → compile RED, `Method not found:
    'routeGuardDecision'` (8 call sites), `Some tests failed.` exit 1.
  - `theme_preferences_test.dart` → **assertion RED, 14 passed / 2 failed**:
    `no legacy role defaults to dark` — `Expected: ThemeMode:<light>
    Actual: ThemeMode:<dark>`, reason `deleted role "cocina" must not carry a
    dark default`; `no saved choice: a legacy role never falls back to dark`
    — same expected/actual at `resolveMode(null, 'cocina')`.
  - `license_strip_guard_test.dart` → **assertion RED, 23 passed / 1 failed**:
    `Expected: <5> Actual: <2>` with reason `role-flows: admin [Usuarios,
    Configuración] + vendedor [Pedidos, Clientes, Días]`.
  - RED-commit analyze: `dart analyze lib` = **0 errors** (102 pre-existing
    warnings/infos in lib untouched); `dart analyze lib test` = 52 errors —
    all 52 are the intentional undefined-symbol references inside the 5 RED
    test files (`routeGuardDecision`, `mapLegacyRoleToAppRole`, `UserRole`,
    `isVendedor`); warnings stayed at 37. RED is red by design (Phase-3
    precedent).
- **Gates (final, commit `7274b18`)**:
  - `dart analyze lib test` = **0 errors, 36 warnings, 65 infos**
    (101 issues). Caps: 0 errors ✅ / ≤47 warnings ✅ (36, −1 vs the 37
    baseline) / ≤86 infos ✅ (65, −9 vs the 74 baseline) — no new
    diagnostics; the drop comes from the deleted SMS-era test/source lines.
  - Full `flutter test` = **162 passed / 0 failed** (`+162: All tests
    passed!`, exit 0).
  - **Count reconciliation vs 138**: 138 + role_mapping 16→19 (+3) +
    theme 18→16 (−2) + NEW route_guard (+23) + workers 8→8 + license guard
    24→24 = **162**. tasks.md 8.1's "≥217" target is stale (it was computed
    against the pre-Phase-4 210/7 baseline); real baseline was **138**, added
    **+24**, now **162**.
- **Mapping source of truth**: Dart `mapLegacyRoleToAppRole`
  (`auth_datasource_impl.dart`) vs SQL `_remapRolesToTwoRoles`
  (`app_database.dart:834-848`) — compared branch by branch: super_admin/admin
  → `admin`; redes/cocina/mesero/domicilio/almacenero/vendedor → `vendedor`;
  ELSE/`default` → `vendedor`. **Identical, no divergent mapping.**
- **Spec-gap conflict found & repinned (not silently skipped)**: the license
  guard's T5 asserted *one menu list with 2 entries for every role* and named
  "for all roles" — the role-flows delta mandates admin=2/vendedor=3, so the
  assertion was updated in the RED commit (it was failing `count=5 vs 2`
  before side_menu changed). Without this repin the suite could never go green
  while honoring the spec. This file was NOT listed in task 5.1's test set —
  recorded here as a forced, spec-driven test update.
- `.g.dart`: `lib/core/database/app_database.g.dart` exists, tracked,
  untouched (`app_database.dart` not modified; no build_runner run).
- `flutter build` NOT run (CDN geo-blocked). `flutter pub get` not needed
  (no pubspec change). No stray PNG staged. Branch created locally only —
  nothing pushed, `main`/`daniel`/`pr/11`–`pr/14`/`feature/hamburguesa-express`
  untouched.



## Phase 5 follow-up — residual legacy role references (2026-10-06)

Fixes the four defect sites that survived Phase 5 (flagged in the Phase 5
notes below), branch `pr/15-roles-guard` from `a5d49fe`, tree clean at start.

- **A — `app_database.dart` `createDefaultAdmin()` (was lines 974–995)**: the
  boot-time helper force-reset the admin row to `'super_admin'` on every
  launch (splash flow + first-login retry), undoing the v16
  `_remapRolesToTwoRoles` migration each boot. Every `'super_admin'` literal
  in the function, its 3 log strings and the line-974 doc comment now say
  `'admin'`. Also dropped `(super_admin)` from the `clearAllDataAdmin` doc
  comment (was line 2866) — the `/// Borrar todo y reiniciar` prefix that the
  license guard T7a pins survives. The v16 CASE (834–848) and the
  legacy-name UPDATEs (821–827) were NOT touched (orchestrator-legit).
- **B — `workers_screen.dart` (17 hits → 0)**: `_roleLabels` = {admin, vendedor}
  (the `'vendedor': 'Redes'` alias dropped → label `'Vendedor'`),
  `_assignableRoles` = `['admin', 'vendedor']`, `_roleVisual` = 2 cases +
  default, edit-dialog fallback `'redes'` → `'vendedor'` (least privilege,
  matches `createUser`'s default), user filtering no longer names
  `super_admin` (admin sees all rows — the 2-role set has no hidden role;
  non-admin → `[]` as defense-in-depth behind the router guard), all copy
  rewritten (`Podés crear usuarios admin y vendedor`, `Elegí el rol del nuevo
  usuario (Admin o Vendedor)`).
  `_isSuperAdmin` → `_isAdmin` (`_currentRole == 'admin'`). Its **6 call
  sites** checked one by one before replacing:
  1. `_loadData` filter — both old branches were IDENTICAL → merged to
     `_isAdmin ? allUsers : []`;
  2. empty-state branch — merged the duplicate admin branches into one
     (`_isAdmin`), legacy copy deleted;
  3. `_buildFab` — duplicate admin branches merged into one `_isAdmin`;
  4. add-dialog `selectableRoles` ternary — collapsed: `_assignableRoles` is
     already the 2-role list, used directly;
  5. add-dialog helper-text `if (_isSuperAdmin)` — made unconditional with
     2-role copy;
  6. edit-dialog role dropdown `if (_isSuperAdmin && !isCurrentUser)` →
     `if (_isAdmin && !isCurrentUser)`. REQUIRED, not cosmetic: with
     `super_admin` unreachable the dropdown would be dead code and NO admin
     could ever change any user's role after creation — role-flows mandates
     admin can create/edit `admin` and `vendedor`.
- **C — `settings_screen.dart:422–423`**: `|| _userRole == 'super_admin'`
  branch + comment → `if (_userRole == 'admin')`. **Pure string/constant
  cleanup with no observable behavior** (the value is unreachable after the
  v16 remap + login mapper) — no test fabricated, stated explicitly.
- **D — `auth_provider.dart:175–178`**: dead getters
  `isRedes/isCocina/isDomicilio/isMesero` removed. FIRST greped `lib/` and
  `test/` for each name: **zero callers existed, zero callers touched**.
  Also fixed the stale `/// (cocina→dark, resto→light)` theme doc comment →
  `(admin y vendedor → light)`. **Pure dead-code removal** — no test
  fabricated, analyzer is the proof.

### Phase 5 follow-up — sweep verdicts (grep `super_admin|redes|cocina|mesero|domicilio|almacenero` over `lib/` + `test/`)

**`lib/` — every remaining hit:**

| File | Hits (line numbers) | Verdict |
|---|---|---|
| `features/workers/.../workers_screen.dart` | was 17 → **0** | **fixed** (`02d1d82`) |
| `features/settings/.../settings_screen.dart` | was 2 → **0** | **fixed** (`82cc394`) |
| `features/auth/.../auth_provider.dart` | was 5 → **0** | **fixed** (`9dbdb4a`: 4 getters + stale comment) |
| `core/database/app_database.dart` | 821, 824, 827 (legacy-name UPDATEs), 837–843 (v16 CASE) = 9 remain; was +8 `createDefaultAdmin` + 1 comment (2866) → **fixed** (`ebefb9f`) | **legit** (orchestrator-listed migration) + **fixed** |
| `features/auth/infrastructure/datasources/auth_datasource_impl.dart` | 17, 20–24 = 6 | **legit** — `mapLegacyRoleToAppRole` mapper |
| `config/theme/app_colors.dart` | 8, 47 = 2 | **legit** — Spanish "cocina" in the color-naming convention, not a role |
| `features/daily_close/.../daily_close_screen.dart` | 532 = 1 | **legit** — UI label "Tiempo medio en cocina" (noun); daily-close rework is Phase 6.3 |
| `features/daily_close/.../daily_close_provider.dart` | 405, 406, 407, 417, 420 = 5 | **legit** — `enCocina` is a legacy ORDER STATE (not a role) inside the kitchen-time metric; Phase 6.3 removes that metric |
| `features/orders/.../order_form_screen.dart` | 19, 22, 26, 298, 370, 386, 394, 866, 881 = 9 | **legit** — "Enviar a cocina" flow copy + "Redes" = social-network channel (not role tokens); screen rework is Phase 7.1 |
| `features/orders/.../order_submit_helpers.dart` | 1, 8, 14 = 3 | **legit** — same submit-flow docs (Phase 7.1) |
| `features/orders/domain/entities/order_state.dart` | 4, 8 = 2 | **legit** — Spanish nouns ("mesa/domicilio", "cocina") in state docs |

**`test/` — every hit: all legit (Phase 5 guard/mapping inputs, never edited):**

| File | Hits | Verdict |
|---|---|---|
| `features/auth/role_mapping_test.dart` | 10–16, 22–47, 61–67, 121 | **legit** — pins `mapLegacyRoleToAppRole` for the 8 legacy values + ELSE |
| `features/workers/workers_route_guard_test.dart` | 17–80 (9) | **legit** — legacy roles as decision-table inputs asserting redirect `/` |
| `config/router/route_guard_test.dart` | 121, 125 | **legit** — `super_admin` must NOT bypass the guard |
| `core/database/schema_v14_additional_tables_test.dart` | 81–87 (7) | **legit** — pins the v16 CASE legacy list |
| `features/theme/theme_preferences_test.dart` | 24–29, 99 | **legit** — legacy roles must default light |
| `features/orders/domain/order_id_test.dart` | 56 | **legit** — `cocina` as an unknown-role input (`throwsArgumentError`) |
| `features/orders/domain/entities/order_state_test.dart` | 64 | **legit** — negative assertion (`enCocina` NOT a state) |
| `architecture/license_strip_guard_test.dart` | 229 | **legit** — comment describing the no-legacy-label assertion |
| `core/database/default_admin_role_test.dart` (NEW) | 53 | **legit** — seeds legacy `'redes'` to prove the repair path |
| `features/workers/workers_screen_roles_guard_test.dart` (NEW) | 46–56 | **legit** — the token list the guard forbids |

### Phase 5 follow-up — evidence

- **Safety net (pre-modification)**: `dart analyze lib test` = **0 errors, 36
  warnings, 65 infos (101)** at `a5d49fe` (matches the recorded Phase 5 gate);
  the target-file subset (license guard + database + role mapping + workers +
  route guard) = **81/81 green**.
- **RED (`16016a9`, both files compile, assertion failures)**:
  `default_admin_role_test` ×3 — `Expected: 'admin' Actual: 'super_admin'` on
  all three paths (keep-seeded / repair-legacy / create-empty), with the boot
  logs `=== created new admin: super_admin ===` and
  `=== updated admin to super_admin ===` captured; workers guard ×4 —
  assignable list `['admin','redes','cocina','mesero','domicilio']`, label map
  7 keys, 10 surviving legacy tokens, fallback `'redes'`. Total **7 failed**.
- **GREEN**: A → `ebefb9f` (3/3 green; architecture+database subset 34/34);
  B → `02d1d82` (workers dir **12/12**; post-fix grep of the screen for the 6
  legacy tokens + `_isSuperAdmin` = **0 hits**; scoped analyze = 0 errors).
- **Final gates (committed tree)**: `dart analyze lib test` = **0 errors, 36
  warnings, 65 infos (101 issues)** — byte-identical to baseline
  (caps: 0 ✅ / ≤47 ✅ (36) / ≤86 ✅ (65)). One warning introduced mid-flight
  (`unused_local_variable` in the new DB test) was fixed in `a461192`
  BEFORE measuring, so the final tree adds zero diagnostics.
- **Full `flutter test` = 169 passed / 0 failed** (`+169: All tests
  passed!`). Reconciliation vs the 162 baseline: 162 +
  `default_admin_role_test` 3 + `workers_screen_roles_guard_test` 4 =
  **169**.
- **`.g.dart`**: `dart run build_runner build
  --build-filter=lib/core/database/app_database.g.dart` executed AFTER the
  `app_database.dart` edit (178s; drift_dev/source_gen, only the pre-existing
  `salesRefs` duplicate-reference warning); `git status`/`git diff` on
  `lib/core/database/app_database.g.dart` → **unchanged** (no table/column
  touched) — left in place, never deleted.
- `flutter build` NOT run (CDN geo-blocked). No branch created/pushed; the 3
  stray root files (`5730bba1`/`6dc69496`/`9b973616`) never staged.

## TDD Cycle Evidence (strict TDD)

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 5b.A | `test/core/database/default_admin_role_test.dart` (new) | Unit (drift in-memory) | ✅ target subset 81/81 green at `a5d49fe` | ✅ `16016a9` — 3 assertion REDs (`Expected 'admin' / Actual 'super_admin'` ×3 paths) | ✅ `ebefb9f` — 3/3 executed | ✅ 3 paths (keep-seeded, legacy-role repair, empty-table create) + role-set totality `everyElement(admin\|vendedor)` | ✅ `a461192` — unused-local removed, still 3/3 |
| 5b.B | `test/features/workers/workers_screen_roles_guard_test.dart` (new, source guard) | Source guard | ✅ same 81/81 | ✅ `16016a9` — 4 assertion REDs (assignable list 5 legacy values, label map 7 keys, 10 tokens, fallback `'redes'`) | ✅ `02d1d82` — workers dir 12/12 | ✅ 4 assertions (assignable list, label keys, token sweep, fallback) | ➖ None needed |
| 5b.C/D | — (pure cleanup: dead branch + dead getters) | — | ✅ analyze 0/36/65 | ➖ None — no observable behavior: `super_admin` unreachable post-v16 remap; 4 getters greped to 0 callers | ✅ final analyze 0/36/65, suite 169/169 | ➖ Not applicable — **stated explicitly, no test fabricated** | ✅ `a461192` |
| 5.1 | `role_mapping_test.dart`, `route_guard_test.dart` (new), `workers_route_guard_test.dart`, `theme_preferences_test.dart` + forced repin of `license_strip_guard_test.dart` T5 | Unit + source guard | ✅ the 4 pre-existing files 66/66 green at `def0633` | ✅ `7478531` — compile RED ×3 files (undefined `mapLegacyRoleToAppRole`/`routeGuardDecision`/`UserRole`+`isVendedor`) + assertion RED ×2 (theme 14/2 dark-default; license guard `Expected <5> Actual <2>`) | ✅ `7274b18` — the 5 files 90/90, full suite 162/162 | ✅ 10 mapping cases (8 values + ELSE + totality), 23 guard cases (5 admin paths × 3 actors + 6 shared + 3 public), 16 theme cases (2-entry matrix, legacy-no-dark, override) | ➖ None needed |
| 5.2 | same 5 test files (GREEN of 5.1) | Unit + source guard | ✅ analyze before edits: 0 errors/37 warnings/74 infos, suite 138 | ✅ `7478531` (shared RED — source untouched at that commit) | ✅ `7274b18` — `dart analyze lib test` 0/36/65, full suite 162/162 | ✅ covered by the 5.1 matrix (guard decision table, mapping ELSE, badge hexes pinned by doc-comment + role-flows) | ➖ None needed (7 files, +107/−218) |
| 4.1 | — (deletions; no test subject) | — | ✅ `dart analyze lib test` 0/47/86 + suite 191 baseline captured first | ➖ None — Phase 4 contract: the safety net IS the analyzer + full suite | ✅ `a3ba44e` — analyze 0/37/74, suite 138/138 | ✅ 33 lib deletions each greped to 0 references | ➖ None needed |
| 4.2 | same net (reference cleanup) | — | ✅ 0/47/86 before edits | ➖ None — no new behavior, removal only | ✅ `a3ba44e` — dead-route grep 0/0/0/0/0/0/0/0/0, XML re-read well-formed | ✅ each of the 9 removed routes greped individually over `lib`+`test` | ➖ None needed |
| 4.3 | `test/architecture/license_strip_guard_test.dart` + `order_notifier_create_order_test.dart` | Source guard + Unit | ✅ analyze 0/47/86, suite 191 | ✅ `8a960c3` (guard pins SMS receiver + help removal; 2 assertions red at `9275ae0`) | ✅ `a3ba44e` — guard 24/24, full suite 138/138 | ✅ 2 guard assertions (SMS receiver, help dir) + 3 re-pinned create-order cases; 53 obsolete tests removed with their subjects | ➖ None needed |
| 3.1 | `test/features/orders/presentation/widgets/order_row_actions_test.dart` | Widget | ✅ Orders suite 50/50 | ✅ `3aee121` (compile: widget missing) | ✅ `997b28e` (4/4) | ✅ 4 cases (3 states + three-actions row) | ➖ None needed |
| 3.2 | same | Widget | ✅ analyze 0/47/86 before edit | ✅ `3aee121` (shared RED) | ✅ executed, orders suite 54/54 | ✅ covered by 3.1 label matrix | ➖ None needed (wiring only, verified by analyze + suite) |
| 2.1 | `test/features/orders/domain/entities/order_state_test.dart` | Unit | N/A (new) | ✅ `5bb9000` | ✅ `d00e50c` | ✅ 17 cases | ➖ None needed |
| 2.2 | same + `order_state` consumers | Unit | ✅ 2.1 green | ✅ `5bb9000` | ✅ `d00e50c` | ✅ covered by 2.1 cases | ➖ None needed |
| 2.3 | `test/features/orders/domain/entities/order_id_test.dart` | Unit | N/A (new) | ✅ `9b16844` | ✅ `ab8a6d9` | ✅ A/V + seq cases | ➖ None needed |
| 2.4 | `test/features/orders/infrastructure/datasources/order_datasource_test.dart` | Unit (drift in-memory) | ✅ prior orders suite | ✅ `62227b0` | ✅ this unit (50/50) | ✅ 14 datasource cases (fechaPedido write×2, valid/invalid/terminal/backwards transitions, unknown estado, updateOrder day field, day queries×2, repo delegation) | ➖ None needed |
| 2.5 | same + 3 notifier test fakes | Unit | ✅ Orders suite run first: 50/50 | ✅ `62227b0` (shared RED) | ✅ executed, 50/50 pass | ✅ covered by 2.4 matrix | ➖ None needed (verify-only run; executor modified no code) |

- **Test summary**: orders suite 54 tests passing (50 after Phase 2 + 4 from 3.1); layers: Unit (drift in-memory executor for datasource) + Widget (`flutter_test`); pure functions added: `_todayIso()`, `orderStateActionLabel`, `nextOrderState`, `buildSmsUri`, `buildTelUri`; `resolveNextRetryCount` removed as dead.
- **Phase 5 test summary**: full suite **162 passing** (138 baseline +24: route_guard +23, role_mapping +3, theme −2); layers: Unit (pure functions: `routeGuardDecision`, `mapLegacyRoleToAppRole`, `defaultThemeForRole`/`resolveMode`) + source guards; pure functions added: `routeGuardDecision`, `_isAdminOnlyPath`, `mapLegacyRoleToAppRole` (renamed), `_roleThemeDefaults`; `workersRedirectDecision`, `mapPosRoleToSmsRole` removed as dead.

## Notes / follow-ups

- Phase 1: legacy `print(` calls in `app_database.dart` (7, pre-existing) remain —
  leave as-is or convert to `debugPrint` in Phase 8 (not required to hit targets).
- Phase 1: 4 newly surfaced pre-existing warnings (unused imports/vars in
  `daily_close_provider.dart`, `daily_close_screen.dart`) left untouched — out of
  Phase 1 scope, already counted within the ≤48 budget.
- `client_management_screen.dart:9` unused import of `order_provider` is
  pre-existing (counted in the 47 warnings; Phase 7 touches this screen).
- 3 stray PNGs at repo root remain untracked by design; never stage them.
- Phase 4.3 deleted `test/features/sms/*` (3) +
  `order_notifier_{resend_sms,sms_persist}_test` (2) = 53 tests, accounted in
  the 191 → 138 reconciliation above;
  `restaurant_order_sms_test` never existed in this repo (stale task text).
- Phase 4 touched `side_menu.dart`? **No** — it needed no edit (it only ever
  listed `/workers` and `/settings`).
- Remaining: Phases 6–8.
- Phase 5 spec-gap (NOT tasked anywhere — flag for the orchestrator):
  `workers_screen.dart` still offers the deleted roles in its picker
  (`_assignableRoles`/labels: `super_admin`, `redes`, `cocina`, `mesero`,
  `domicilio`; default `'redes'`) and `settings_screen.dart:423` still checks
  `role == 'super_admin'`. Both contradict the 2-role allowed set and will
  surface in 8.1's dead-role grep; no task 5/6/7 covers them.
  **RESOLVED 2026-10-06 by the Phase 5 follow-up above** (sites B and C, plus
  A `createDefaultAdmin` and D dead getters in the same unit); the residual
  sweep now reads 0 role-token hits in `workers_screen`/`settings_screen`/
  `auth_provider`.
- Phase 5 known transient: the vendedor `Días` entries (menu + dashboard)
  point at `/days`, whose route/screens land in task 6.3 — tapping them
  between this PR and the Phase 6 PR 404s. Accepted under the chain
  (`feature-branch-chain`, PR5 follows immediately).
- Phase 5 guard semantics: `routeGuardDecision` guards ONLY the admin-only
  path set (unauthenticated → `/login` on those); unauthenticated access to
  shared paths is left to the router exactly as before this phase (pre-existing
  behavior, not part of the design decision table).
- Phase 3 touched only `order_row_actions.dart`, `order_history_screen.dart`
  and its new test: zero out-of-scope files, zero new analyzer diagnostics.
  The history screen had no per-row actions before, so nothing was removed
  and no cancel/notify/delete handler (Phases 4/7) was orphaned.

## Commits

### Phase 1 (branch `pr/11-schema-v16`)
- `9035d42` — `test: rewrite schema tests for v16 (red)` (RED).
- `f149a5e` — `feat: migrate schema to v16 and drop restaurant-only tables` (GREEN).

### Phase 2 (branch `pr/12-orders-core`)
- `5bb9000` — `test: define three-state order machine expectations (red)` (2.1 RED).
- `d00e50c` — `feat: collapse orders to three-state model with fechaPedido` (2.1/2.2 GREEN).
- `9b16844` — `test: define order id builder format expectations (red)` (2.3 RED).
- `ab8a6d9` — `feat: add buildOrderId for A/V day-sequential order ids` (2.3 GREEN).
- `62227b0` — `test: define day-field and validated-transition datasource expectations (red)` (2.4 RED).
- 2.5 GREEN: one `feat:` (source) + one `test:` (test fakes) — see git log on `pr/12-orders-core`.

### Phase 3 (branch `pr/13-row-actions`, from `pr/12-orders-core` @ `f291af9`)
- `3aee121` — `test: define order row state-button label expectations (red)` (3.1 RED; +110, the new test file only).
- `997b28e` — `feat: add OrderRowActions with state-driven labels and sms/tel intents` (3.2 GREEN part 1; +113, the widget).
- `c5a012e` — `feat: wire OrderRowActions into order history rows` (3.2 GREEN part 2; +48, `order_history_screen.dart`).
- Docs commit: `tasks.md` `[x]` 3.1/3.2 + this `apply-progress.md` Phase 3 merge.
- Code total: 271 added lines (under the 400-line review budget for this slice).

### Phase 4 (branch `pr/14-deletions`, from `pr/13-row-actions` @ `5d7c061`)
- `8a960c3` — `test: pin SMS receiver and help feature removal in license guard (red)` (4.3 RED, pre-existing before this unit).
- `9275ae0` — `test: drop SMS-era tests and align create-order expectations with SMS-free flow` (4.3 test half; −947/+16, 6 files: 5 deletions + 1 fix).
- `a3ba44e` — `feat: delete SMS, contacts, exports, help and expenses surfaces with dead routes` (4.1+4.2 and the GREEN of `8a960c3`; −8075/+22, 44 files: 33 deletions + 11 reference-cleanup edits).
- Docs commit: `tasks.md` `[x]` 4.1/4.2/4.3 + this `apply-progress.md` Phase 4 merge.
- Commit order note: the `test:` unit lands first because the `feat:`-only
  intermediate would not compile (`dart analyze lib test` would flag the
  deleted `sms_service.dart` imports). At `9275ae0` the tree compiles and runs
  136/138 with only the 2 intended guard RED assertions failing; `a3ba44e`
  flips them GREEN. Both commits compile; only `9275ae0` is red, by design.

### Phase 5 (branch `pr/15-roles-guard`, from `pr/14-deletions` @ `def0633`)
- `7478531` — `test: pin two-role remap, route guard decision table and light-only theme defaults (red)` (5.1 RED; 5 files, +469/−143: 4 rewritten/updated + 1 new `route_guard_test.dart`).
- `7274b18` — `feat: collapse to two roles with admin-only route guard and role-based menus` (5.2 GREEN + turning 5.1 green; 7 files, +107/−218).
- Docs commit: `tasks.md` `[x]` 5.1/5.2 + this `apply-progress.md` Phase 5 merge.
- Code+test total for the slice: +576/−361 (negative delta; well under the 400-line review budget concern because 361 lines are deletions of dead role UI).
- Both commits pushed nowhere — local branch only.

### Phase 5 follow-up (branch `pr/15-roles-guard`, from `a5d49fe`)
- `16016a9` — `test: pin default admin role and workers two-role options (red)` (RED; 2 new test files, +160).
- `ebefb9f` — `fix(db): stop createDefaultAdmin resetting the admin role to super_admin` (site A GREEN; `app_database.dart` +11/−9).
- `02d1d82` — `fix(workers): collapse screen roles, defaults and guard to admin and vendedor` (site B GREEN; `workers_screen.dart` +26/−76).
- `82cc394` — `refactor(settings): drop dead super_admin branch from danger zone guard` (site C; +2/−2).
- `9dbdb4a` — `refactor(auth): remove dead legacy role getters and stale theme comment` (site D; +1/−5).
- `a461192` — `test: assert admin precondition without unused local` (refactor; +1/−1).
- Docs commit: this `apply-progress.md` merge.
- Code+test total: 6 files, +200/−92. Nothing pushed; the 3 stray root files never staged.
