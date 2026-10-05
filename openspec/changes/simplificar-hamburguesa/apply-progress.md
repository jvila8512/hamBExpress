# Apply Progress — simplificar-hamburguesa

Branch: `pr/11-schema-v16` · Unit: Phase 1 (Schema v16) · Mode: strict TDD
Last updated: 2026-10-04

## Status

| Phase | Tasks | State |
|---|---|---|
| 1. Schema v16 | 1.1–1.3 | ✅ Done (commit below) |
| 2. Orders core | U2 | ⬜ Pending |
| 3. Roles | U4 | ⬜ Pending |
| 4. Days | U5 | ⬜ Pending |
| 5. Screens | U6 | ⬜ Pending |
| 6. Cleanup | — | ⬜ Pending |
| 7. Integration | — | ⬜ Pending |
| 8. Reconciliation | — | ⬜ Pending (analyzers/targets below) |

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

## Evidence

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

## Notes / follow-ups

- Legacy `print(` calls in `app_database.dart` (7, pre-existing) remain — leave
  as-is or convert to `debugPrint` in Phase 8 (not required to hit targets).
- 4 newly surfaced pre-existing warnings (unused imports/vars in
  `daily_close_provider.dart`, `daily_close_screen.dart`) left untouched — out of
  Phase 1 scope, already counted within the ≤48 budget.
- 3 stray PNGs at repo root remain untracked by design; never stage them.

## Commit

- `9035d42` — `test: rewrite schema tests for v16 (red)` (RED).
- Phase 1 GREEN commit — see git log on `pr/11-schema-v16` (schema + de-dangling
  + license_strip_guard test, atomic so the tree always compiles).
