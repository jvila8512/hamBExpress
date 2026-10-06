# Apply Progress — simplificar-hamburguesa

Units: Phase 1 (Schema v16, branch `pr/11-schema-v16`) · Phase 2 (Orders Core 2.1–2.5, branch `pr/12-orders-core`) · Phase 3 (Row Actions 3.1–3.2, branch `pr/13-row-actions`) · Phase 4 (Deletions 4.1–4.3, branch `pr/14-deletions`)
Mode: strict TDD · Last updated: 2026-10-06

## Status

| Phase | Tasks | State |
|---|---|---|
| 1. Schema v16 | 1.1–1.3 | ✅ Done (commits on `pr/11-schema-v16`) |
| 2. Orders core | 2.1–2.5 | ✅ Done (commits below) |
| 3. Row actions | 3.1–3.2 | ✅ Done (commits below) |
| 4. Deletions | 4.1–4.3 | ✅ Done (commits below) |
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


## TDD Cycle Evidence (strict TDD)

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
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
- Remaining: Phases 5–8.
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
