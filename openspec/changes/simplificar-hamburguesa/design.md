# Design: Simplificar Hamburguesa — Two-Role, Day-Based Order Model

## Technical Approach

Collapse the SMS-era restaurant app into two roles (`admin`, `vendedor`) and a day-centric order flow. Schema goes **v15 → v16** (proposal's v14→v15 is stale — `app_database.dart:647` already declares 15): add `fecha_pedido`, truncate legacy orders, drop seven dead tables, remap roles. Nine states become `pedido → confirmado → recogido`; SMS sending becomes `sms:`/`tel:` intents; new `days` feature adds `/days` + `/days/:date`. All 10 delta specs covered; strict TDD against 210 pass / 7 fail (the 7 are updated here, never counted as regressions).

## Architecture Decisions

| Topic | Options | Decision & rationale |
|---|---|---|
| Schema bump | v15 (proposal) / v16 | **v16** — code already at 15; a v15 migration would never run. |
| Legacy orders | Remap / truncate | **Truncate**: DELETE restaurant orders+items, `DROP IF EXISTS` POS `orders`/`order_items` — spec forbids state remapping. |
| Dead tables | Keep classes / delete | **Delete 7 classes + `@DriftDatabase` entries** (TrustedContacts, SmsMessages, OrderStateHistory, RestaurantTables, DailyExpenses, DailyPurchases, DailyPayroll); analyzer catches dangling refs. `PriceHistory` stays (unlisted). |
| `fecha_pedido` | Recreate / addColumn | **`addColumn` `DEFAULT ''`, then DELETE** — SQLite rejects NOT NULL adds without default; Dart sets today on insert. |
| Client name/cell | Columns / join | **Join `clienteId → RestaurantClients`** — no duplicated data drifting on edit. |
| Order ID | uuid / builder | **`buildOrderId` → `A1-1003-007`**: `A`/`V` from stored role, originSeq = device ordinal (default 1), dailySeq = count of ids with `-{MMDD}-` + 1. |
| Day metrics | UI / pure fn | **`computeDayMetrics(orders, dateIso, costByProduct)`** — cost injected from Products; upsert `DailySummaries` by ISO date, add `topClientesJson`. |
| Close guard | UI / data layer | **Data layer**: `closeDay` throws before any write when role ≠ `admin`. |
| Route guard | Per-route / one fn | **`workersRedirectDecision` → `routeGuardDecision`**: admin-only `/workers`, `/settings`, `/products*`; `/orders`, `/clients`, `/days` open to both. |
| Row actions | Extra buttons / widget | **Exactly three** in shared `OrderRowActions` (SMS `sms:`, dialer `tel:`, label Confirmar→Marcar recogido→Recogido); day moves live in new `/orders/edit/:id`. Badge uses spec hexes both themes. |

## Data Flow

    OrderForm ──buildOrderId──→ OrderRepository ──→ restaurant_orders (fecha_pedido)
    /days ──group fecha_pedido ∪ DailySummaries──→ DayList ──tap──→ /days/:date
    DayDetail ──OrderRowActions──→ updateOrderState (canTransitionTo; unknown estado → pedido)
    /daily-close?date=D ──computeDayMetrics──→ admin ──→ upsert DailySummaries

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/features/days/presentation/**` | Create | Day list/detail screens + providers |
| `order_row_actions.dart`, `order_id.dart` (orders feature) | Create | 3-action row; ID builder |
| `lib/core/database/app_database.dart` + regen `.g.dart` | Modify | v16 addColumn/truncates/7 drops/role CASE; insert-only `admin` seed; `+fechaPedido`, −9 columns |
| `orders/domain/entities/{order_state,restaurant_order}.dart` | Modify | 3 states; `fechaPedido`; drop tipoPedido/mesaId/metodoPago/motivoCancelacion/sms*/canalOrigen/horaSolicitada |
| `order_repository(_impl).dart`, `order_datasource.dart` | Modify | Day queries + write, validated `updateOrderState`, unknown→`pedido`, drop `markSms*` |
| `order_provider.dart` | Modify | Drop SMS/contact deps; day loaders |
| `order_form_screen.dart`, `order_history_screen.dart` | Modify | Day picker, edit mode, no categories/SMS; 3-state filters + row actions |
| `lib/config/router/app_router.dart` | Modify | Remove 9 routes; add `/days`, `/days/:date`, `/orders/edit/:id`; `routeGuardDecision` |
| `lib/main.dart`, `pubspec.yaml`, `AndroidManifest.xml` | Modify | Drop SMS receiver, `telephony_sdt`, SMS permissions |
| `side_menu.dart`, `home_screen.dart` | Modify | Admin=[Usuarios, Configuración]; vendedor=[Pedidos, Clientes, Días]; 2 dashboards, `Nuevo Pedido` |
| `lib/features/daily_close/**` | Modify | Day-parameterized metrics, no tabs/EF-TR; Cerrar día, 30/30/40, top clientes |
| `theme_provider.dart`, `status_badge.dart` | Modify | Matrix → 2 light entries; 3-state badge hexes |
| `lib/features/auth/**`, `workers_screen.dart`, `settings_screen.dart` | Modify | 2-role enum+remap; admin-only checks |
| `lib/features/products/presentation/**` | Modify | Flat catalog, name+price form; drop categories/import nav |
| `lib/features/{contacts,sms,exports,expenses}/**`, categories/import screens+provider, kitchen/delivery/tracking screens, `order_timer.dart`, `help_screen.dart` | Delete | ~30 files per REMOVED requirements |
| `test/features/sms/*`, `order_notifier_{resend_sms,sms_persist}_test`, `restaurant_order_sms_test` | Delete | Feature gone |
| `test/core/database/schema_v14*.dart` | Modify | Assert v16/drops/`fecha_pedido` — turns the 7 known failures green |
| `license_strip_guard_test`, `workers_route_guard_test`, `role_mapping_test`, `theme_preferences_test`, `order_state_test`, `daily_close_totals_test`, `order_datasource_test`, `order_notifier_create_order_test` | Modify | v16/guard/2-role/light-only/3-state/totals/no-SMS |
| New: `order_id_test`, `day_metrics_test`, `route_guard_test`, `state_action_labels_test`, close-rejection test | Create | Pure fns + data-layer rejection |

## Interfaces / Contracts

```dart
enum OrderState { pedido, confirmado, recogido }        // pedido→confirmado→recogido (terminal)
String buildOrderId({required String role, required int originSeq, required String mmdd, required int dailySeq});
DayMetrics computeDayMetrics(List<RestaurantOrder> orders, String dateIso, Map<String, double> costByProduct);
Future<void> closeDay(String dateIso, {required String actorRole});   // StateError unless 'admin'
String? routeGuardDecision({required String currentPath, required String role, required bool authenticated});
// Row intents via url_launcher: 'sms:<cell>?body=<summary>' / 'tel:<cell>'
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | ID, transitions, metrics, labels, role remap, theme | Pure fns, hand-rolled fakes |
| Data | `fechaPedido` write, rejected transition unchanged, unknown→`pedido`, vendedor close rejected | Fake DB/repository |
| Widget | Badge hexes, role menus, day list status, three actions | `flutter_test` |
| Schema | v16, drops, preserved rows | Updated `schema_v14*.dart` (source-level; avoids DSL `primaryKey` trap) |
| Regression | Full suite; `dart analyze lib test` = 0 errors, ≤47 warnings, ≤86 infos | `flutter test` |

## Migration / Rollout

One release, no flags. v16: addColumn → DELETE order rows → 7+POS drops → idempotent role CASE (8 values, logged) → build_runner → update schema/guard tests. `Users`, `RestaurantClients`, `Products`, `Categories`, `PriceHistory` untouched; fresh installs seed one `admin` only when `Users` is empty, never overwriting credentials.

## Open Questions

- [ ] `A1` second sequence read as stable per-device origin ordinal (default `1`) — confirm.
- [ ] "Client name/cell on header" satisfied via `clienteId` join, not columns — confirm literal reading.
