# Tasks: Simplificar Hamburguesa

## Review Workload Forecast

Estimated changed lines: ~6,500 (excl. generated `.g.dart` regen)
400-line budget risk: High
Chained PRs recommended: Yes
Decision needed before apply: Yes
Chain strategy: pending
Recommended delivery_strategy: ask-on-risk

Work units → PRs: U1 schema→PR1; U2 orders core+row actions→PR2; U3 deletions→PR3; U4 roles/guard/menus/theme→PR4; U5 days+close→PR5; U6 forms/catalog+gate→PR6.

## Phase 1: Schema v16

- [x] 1.1 RED: rewrite `test/core/database/schema_v14{,_additional_tables}_test.dart` for v16, `fecha_pedido`, 7 drops, preserved Users/Clients/Products (auth·Migration; order·Legacy Data Migration); verify red.
- [x] 1.2 GREEN: `app_database.dart` v16 — addColumn `fecha_pedido`/`topClientesJson`, DELETE legacy orders, DROP 7 tables + POS orders/order_items, logged 8-value role CASE, seed admin iff Users empty; delete 7 table classes.
- [x] 1.3 `dart run build_runner build`; run `flutter test test/core/database` once → 7 baseline failures green.

## Phase 2: Orders Core

- [x] 2.1 RED: `order_state_test.dart` — valid `pedido→confirmado→recogido`, invalid/terminal rejected, unknown→pedido (order·Three-State).
- [x] 2.2 GREEN: `order_state.dart` enum + `canTransitionTo`; `restaurant_order.dart` +`fechaPedido`, drop tipoPedido/mesaId/metodoPago/motivoCancelacion/sms*/canalOrigen/horaSolicitada (order·Day Field).
- [x] 2.3 RED→GREEN: new `order_id_test.dart` then `order_id.dart` `buildOrderId` A/V, originSeq=1, dailySeq (order·ID Format).
- [x] 2.4 RED: `order_datasource_test.dart` — fechaPedido write, rejected transition unchanged, unknown→pedido (order·Three-State/Day Field).
- [x] 2.5 GREEN: `order_datasource.dart` + `order_repository(_impl).dart` — validated `updateOrderState`, day queries/write, drop `markSms*`.

## Phase 3: Row Actions

- [x] 3.1 RED: new `state_action_labels_test.dart` — Confirmar / Marcar recogido / Recogido (order·Row Actions).
- [x] 3.2 GREEN: create `orders/presentation/widgets/order_row_actions.dart` (`sms:<cell>?body=`, `tel:<cell>`, label/advance); wire `order_history_screen.dart`.

## Phase 4: Deletions

- [ ] 4.1 Delete 32 files: `features/{sms,contacts,exports,help}` (21), `features/expenses/**` (2), `categories_screen|category_form_screen|import_products_screen|categories_provider`, `kitchen_queue_screen|delivery_list_screen|order_tracking_screen`, `order_timer.dart`, `export_options_dialog.dart`, barrel entries (sms-protocol, trusted-contacts REMOVED).
- [ ] 4.2 Clean every reference: `main.dart` receiver/SmsService, `app_router.dart` dead routes (/products/import, /categories*, /expenses, /orders/tracking, /kitchen, /delivery, /contacts, /exports, /help), `order_provider.dart`, `order_form_screen.dart`, `side_menu.dart`, `home_screen.dart`, `pubspec.yaml` telephony_sdt, `AndroidManifest.xml` SMS perms.
- [ ] 4.3 Delete `test/features/sms/*`, `order_notifier_{resend_sms,sms_persist}_test`, `restaurant_order_sms_test`; fix `license_strip_guard_test.dart`, `order_notifier_create_order_test.dart`; `dart analyze lib test` = 0 errors.

## Phase 5: Roles, Guard, Menus

- [ ] 5.1 RED: extend `role_mapping_test.dart` (8 values), new `route_guard_test.dart`, update `workers_route_guard_test.dart`, `theme_preferences_test.dart` (auth·Route Guard; theme-preferences).
- [ ] 5.2 GREEN: `user.dart` 2-role enum; `routeGuardDecision` in `app_router.dart`; 2-role `side_menu.dart`/`home_screen.dart` + Nuevo Pedido; `theme_provider.dart` 2 light; `status_badge.dart` 3 hexes (role-flows).

## Phase 6: Days + Close

- [ ] 6.1 RED: new `day_metrics_test.dart` (ventas excludes pedido, ganancias, top clientes, zeros) + vendedor close-rejected test; update `daily_close_totals_test.dart` (day-management·Metrics/Persisting; daily-close·Admin-Only).
- [ ] 6.2 GREEN: pure `computeDayMetrics`, `closeDay` data-layer admin guard, `DailySummaries` upsert.
- [ ] 6.3 GREEN UI: create `lib/features/days/presentation/**` (+ routes /days, /days/:date, /orders/edit/:id); rework `daily_close/**` day-param, no tabs/EF-TR, 30/30/40, Top de Clientes.

## Phase 7: Forms + Catalog

- [ ] 7.1 `order_form_screen.dart` day picker/edit + client name/cell via `clienteId` JOIN; `order_history_screen.dart` 3-state filters; `order_provider.dart` day loaders (client-management; order·Day Field).
- [ ] 7.2 `products_screen.dart`/`product_form_screen.dart`: name+price only, no code/category/import (products·Generic Product, Identification).

## Phase 8: Final Verification

- [ ] 8.1 Run `flutter test` ONCE + `dart analyze lib test`: reconcile vs 210/7 baseline (target ≥217 pass / 0 fail; 0 errors, ≤48 warnings, ≤86 infos); Grep-scan zero refs to deleted roles, JSON SMS parser, dead routes.
