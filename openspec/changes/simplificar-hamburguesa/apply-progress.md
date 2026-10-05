# Apply Progress — simplificar-hamburguesa

Units: Phase 1 (Schema v16, branch `pr/11-schema-v16`) · Phase 2 (Orders Core 2.1–2.5, branch `pr/12-orders-core`) · Phase 3 (Row Actions 3.1–3.2, branch `pr/13-row-actions`)
Mode: strict TDD · Last updated: 2026-10-05

## Status

| Phase | Tasks | State |
|---|---|---|
| 1. Schema v16 | 1.1–1.3 | ✅ Done (commits on `pr/11-schema-v16`) |
| 2. Orders core | 2.1–2.5 | ✅ Done (commits below) |
| 3. Row actions | 3.1–3.2 | ✅ Done (commits below) |
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

## TDD Cycle Evidence (strict TDD)

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 3.1 | `test/features/orders/presentation/widgets/order_row_actions_test.dart` | Widget | ✅ Orders suite 50/50 | ✅ `3aee121` (compile: widget missing) | ✅ `997b28e` (4/4) | ✅ 4 cases (3 states + three-actions row) | ➖ None needed |
| 3.2 | same | Widget | ✅ analyze 0/47/86 before edit | ✅ `3aee121` (shared RED) | ✅ executed, orders suite 54/54 | ✅ covered by 3.1 label matrix | ➖ None needed (wiring only, verified by analyze + suite) |
| 2.1 | `test/features/orders/domain/entities/order_state_test.dart` | Unit | N/A (new) | ✅ `5bb9000` | ✅ `d00e50c` | ✅ 17 cases | ➖ None needed |
| 2.2 | same + `order_state` consumers | Unit | ✅ 2.1 green | ✅ `5bb9000` | ✅ `d00e50c` | ✅ covered by 2.1 cases | ➖ None needed |
| 2.3 | `test/features/orders/domain/entities/order_id_test.dart` | Unit | N/A (new) | ✅ `9b16844` | ✅ `ab8a6d9` | ✅ A/V + seq cases | ➖ None needed |
| 2.4 | `test/features/orders/infrastructure/datasources/order_datasource_test.dart` | Unit (drift in-memory) | ✅ prior orders suite | ✅ `62227b0` | ✅ this unit (50/50) | ✅ 14 datasource cases (fechaPedido write×2, valid/invalid/terminal/backwards transitions, unknown estado, updateOrder day field, day queries×2, repo delegation) | ➖ None needed |
| 2.5 | same + 3 notifier test fakes | Unit | ✅ Orders suite run first: 50/50 | ✅ `62227b0` (shared RED) | ✅ executed, 50/50 pass | ✅ covered by 2.4 matrix | ➖ None needed (verify-only run; executor modified no code) |

- **Test summary**: orders suite 54 tests passing (50 after Phase 2 + 4 from 3.1); layers: Unit (drift in-memory executor for datasource) + Widget (`flutter_test`); pure functions added: `_todayIso()`, `orderStateActionLabel`, `nextOrderState`, `buildSmsUri`, `buildTelUri`; `resolveNextRetryCount` removed as dead.

## Notes / follow-ups

- Phase 1: legacy `print(` calls in `app_database.dart` (7, pre-existing) remain —
  leave as-is or convert to `debugPrint` in Phase 8 (not required to hit targets).
- Phase 1: 4 newly surfaced pre-existing warnings (unused imports/vars in
  `daily_close_provider.dart`, `daily_close_screen.dart`) left untouched — out of
  Phase 1 scope, already counted within the ≤48 budget.
- `client_management_screen.dart:9` unused import of `order_provider` is
  pre-existing (counted in the 47 warnings; Phase 7 touches this screen).
- 3 stray PNGs at repo root remain untracked by design; never stage them.
- Remaining: Phases 4–8. Phase 4.3 still owns deleting
  `test/features/sms/*`, `order_notifier_{resend_sms,sms_persist}_test`,
  `restaurant_order_sms_test` — hence those files were kept (not deleted) here.
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
