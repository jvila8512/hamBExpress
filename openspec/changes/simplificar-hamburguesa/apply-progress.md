# Apply Progress — simplificar-hamburguesa

Units: Phase 1 (Schema v16, branch `pr/11-schema-v16`) · Phase 2 (Orders Core 2.1–2.5, branch `pr/12-orders-core`)
Mode: strict TDD · Last updated: 2026-10-05

## Status

| Phase | Tasks | State |
|---|---|---|
| 1. Schema v16 | 1.1–1.3 | ✅ Done (commits on `pr/11-schema-v16`) |
| 2. Orders core | 2.1–2.5 | ✅ Done (commits below) |
| 3. Row actions | 3.1–3.2 | ⬜ Pending |
| 4. Deletions | 4.1–4.3 | ⬜ Pending |
| 5. Roles, guard, menus | 5.1–5.2 | ⬜ Pending |
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

## TDD Cycle Evidence (strict TDD)

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 2.1 | `test/features/orders/domain/entities/order_state_test.dart` | Unit | N/A (new) | ✅ `5bb9000` | ✅ `d00e50c` | ✅ 17 cases | ➖ None needed |
| 2.2 | same + `order_state` consumers | Unit | ✅ 2.1 green | ✅ `5bb9000` | ✅ `d00e50c` | ✅ covered by 2.1 cases | ➖ None needed |
| 2.3 | `test/features/orders/domain/entities/order_id_test.dart` | Unit | N/A (new) | ✅ `9b16844` | ✅ `ab8a6d9` | ✅ A/V + seq cases | ➖ None needed |
| 2.4 | `test/features/orders/infrastructure/datasources/order_datasource_test.dart` | Unit (drift in-memory) | ✅ prior orders suite | ✅ `62227b0` | ✅ this unit (50/50) | ✅ 14 datasource cases (fechaPedido write×2, valid/invalid/terminal/backwards transitions, unknown estado, updateOrder day field, day queries×2, repo delegation) | ➖ None needed |
| 2.5 | same + 3 notifier test fakes | Unit | ✅ Orders suite run first: 50/50 | ✅ `62227b0` (shared RED) | ✅ executed, 50/50 pass | ✅ covered by 2.4 matrix | ➖ None needed (verify-only run; executor modified no code) |

- **Test summary**: orders suite 50 tests passing; layers: Unit only (drift in-memory executor for datasource); pure functions added: `_todayIso()`, `resolveNextRetryCount` removed as dead.

## Notes / follow-ups

- Phase 1: legacy `print(` calls in `app_database.dart` (7, pre-existing) remain —
  leave as-is or convert to `debugPrint` in Phase 8 (not required to hit targets).
- Phase 1: 4 newly surfaced pre-existing warnings (unused imports/vars in
  `daily_close_provider.dart`, `daily_close_screen.dart`) left untouched — out of
  Phase 1 scope, already counted within the ≤48 budget.
- `client_management_screen.dart:9` unused import of `order_provider` is
  pre-existing (counted in the 47 warnings; Phase 7 touches this screen).
- 3 stray PNGs at repo root remain untracked by design; never stage them.
- Remaining: Phases 3–8. Phase 4.3 still owns deleting
  `test/features/sms/*`, `order_notifier_{resend_sms,sms_persist}_test`,
  `restaurant_order_sms_test` — hence those files were kept (not deleted) here.

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
