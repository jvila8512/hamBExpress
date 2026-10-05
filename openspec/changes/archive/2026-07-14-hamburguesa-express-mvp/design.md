# Design: Hamburguesas Express SMS Ordering — MVP

## Technical Approach

Single codebase (`etecsa` package preserved), schema v14 removes POS tables and adds SMS-order tables. Role-gated UI via GoRouter redirects keyed to new role enum (`admin`, `redes`, `cocina`, `domicilio`, `mesero`). SMS transport via `telephony` package + `BroadcastReceiver` with JSON minified payloads, ACK timer, and dedup by order ID. Existing Riverpod + Drift patterns followed.

## Architecture Decisions

| Option | Tradeoffs | Decision |
|--------|-----------|----------|
| **Package rename** | Rename breaks all imports, git blame; keep reduces risk | Keep `etecsa` |
| **SMS transport** | `telephony` (mature, bg receive) vs raw `SmsManager` (no bg) | `telephony` — background reception required |
| **Order state machine** | Enum + explicit transitions vs string field | Enum `OrderState` with `validTransitions` map |
| **Drift tables: remove or keep POS** | Remove = clean but migration risk; keep = tech debt | Remove all POS tables in v14 migration |
| **Restaurant clients** | New Drift table vs reuse `Clientes` table | New `RestaurantClient` table — no FK to license `Clientes` |
| **Daily close persistence** | Re-aggregate on every open vs cache table | Cache table `DailySummaries` keyed by date |
| **Role gating** | GoRouter redirect per route vs provider-based shell | GoRouter redirect (existing pattern) + per-role home screen |
| **SMS dedup** | Check `id` in DB before processing | `id` uniqueness constraint on `RestaurantOrders` |

## Data Flow

```
REDES                      COCINA                   DOMICILIO              ADMIN
  │                          │                        │                      │
  ├─ Create order ─────────→│                        │                      │
  │  (REGISTRADO)            │                        │                      │
  │  Send PED SMS ─────────→│                        │                      │
  │  Start ACK timer         │                        │                      │
  │                          ├─ Parse PED              │                      │
  │                          ├─ Dedup check            │                      │
  │                          ├─ Persist EN_COCINA      │                      │
  │  ←── ACK SMS ────────────┤                        │                      │
  │                          ├─ Show in queue UI       │                      │
  │                          │                        │                      │
  │                          ├─ Mark HECHO ──────────→│                      │
  │                          │  Send HEC SMS          │                      │
  │                          │                        ├─ Parse HEC             │
  │                          │                        ├─ Update EN_CAMINO      │
  │                          │                        ├─ Show delivery list    │
  │                          │                        │                        │
  │                          │                        ├─ Mark ENTREGADO ─────→│
  │  ←── ENT SMS ────────────┤                        │  Send ENT SMS         │
  │                          │                        │                        │
  │  Close order             │                        │    DAILY CLOSE:        │
  │                          │                        │    Aggregate ENT orders│
  │                          │                        │    + expenses/purchases│
  │                          │                        │    + payroll           │
  │                          │                        │    → 30/30/40 split    │
```

## File Changes

### New Modules (each follows domain/infrastructure/presentation structure)

| File | Action | Description |
|------|--------|-------------|
| `lib/features/sms/domain/entities/sms_payload.dart` | Create | `SmsPayload` class: t, id, cl, tl, dr, rf, it, hr, pg, mt, mo |
| `lib/features/sms/domain/services/sms_parser.dart` | Create | Parse JSON → `SmsPayload`, pipe-delimited fallback |
| `lib/features/sms/domain/services/sms_serializer.dart` | Create | `SmsPayload` → minified JSON string |
| `lib/features/sms/infrastructure/services/sms_service.dart` | Create | Wrap `telephony`: send, bg listener, ACK timer |
| `lib/features/sms/infrastructure/services/broadcast_receiver.dart` | Create | Android bg receiver, origin filter, dispatch |
| `lib/features/orders/domain/entities/order_state.dart` | Create | `enum OrderState` with transitions |
| `lib/features/orders/domain/entities/restaurant_order.dart` | Create | Order entity with state, client, items, timestamps |
| `lib/features/orders/domain/repositories/order_repository.dart` | Create | Abstract repo |
| `lib/features/orders/infrastructure/datasources/order_datasource.dart` | Create | Drift datasource |
| `lib/features/orders/infrastructure/repositories/order_repository_impl.dart` | Create | Impl |
| `lib/features/orders/presentation/providers/order_provider.dart` | Create | Riverpod notifier |
| `lib/features/orders/presentation/screens/order_form_screen.dart` | Create | Redes order form |
| `lib/features/orders/presentation/screens/kitchen_queue_screen.dart` | Create | Cocina queue |
| `lib/features/orders/presentation/screens/delivery_list_screen.dart` | Create | Domicilio delivery list |
| `lib/features/orders/presentation/screens/order_history_screen.dart` | Create | All roles |
| `lib/features/clients/` | Create | Same domain/infra/presentation pattern |
| `lib/features/contacts/` | Create | Trusted contacts CRUD |
| `lib/features/daily_close/` | Create | Daily close panel, aggregation, profit split |

### Modified Files

| File | Action | Description |
|------|--------|-------------|
| `pubspec.yaml` | Modify | Add `telephony: ^0.8.0` (check latest) |
| `lib/core/database/app_database.dart` | Modify | **Schema v14**: add 7 new tables, drop 16 POS tables, add `codigoCorto` to Products, role data migration, seed food categories |
| `lib/config/router/app_router.dart` | Modify | Add SMS-order routes, remove POS routes, update role redirects |
| `lib/features/auth/domain/entities/user.dart` | Modify | Add `isRedes`, `isCocina`, `isDomicilio`, `isMesero` getters |
| `lib/features/auth/presentation/providers/auth_provider.dart` | Modify | Update role checks for SMS roles |
| `lib/features/auth/infrastructure/datasources/auth_datasource_impl.dart` | Modify | Role mapping `vendedor→redes`, `almacenero→cocina`, `super_admin→admin` |
| `lib/features/home/presentation/screens/home_screen.dart` | Modify | Role-gated home screen per role |
| `lib/features/products/presentation/screens/product_form_screen.dart` | Modify | Add `codigoCorto` field |
| `lib/features/products/presentation/providers/products_provider.dart` | Modify | Include `codigoCorto` in CRUD |
| `lib/features/expenses/` | Modify | Extend for daily close integration |
| `lib/features/shared/services/KeyValueStorageService.dart` | Keep | Reuse existing |

### Deleted Files (entire directories)

| Path | Reason |
|------|--------|
| `lib/features/pos/` | POS screen, prefactura, orders history replaced by SMS orders |
| `lib/features/inventory/` | FIFO inventory, stock movements — not needed for restaurant |
| `lib/features/workers/` | Workers management replaced by user management |
| `lib/features/sync/` | Despachos, rendiciones, sync — all POS-specific |
| `lib/features/reports/screens/sessions_screen.dart` | POS session reports |
| `lib/features/reports/screens/session_detail_screen.dart` | POS session detail |

### Database Schema v14 Changes

**New tables** (12):
- `restaurant_clients` — clientes del restaurante (nombre, telefono, direccion, referencia)
- `restaurant_orders` — pedidos SMS con estado machine
- `restaurant_order_items` — items de cada pedido
- `restaurant_tables` — mesas del local (numero, capacidad, estado libre/ocupada, ubicacion)
- `order_state_history` — auditoría de cambios de estado (pedidoId, estado, timestamp, usuarioId, viaSms)
- `trusted_contacts` — whitelist de teléfonos por rol
- `sms_messages` — registro de SMS enviados/recibidos
- `price_history` — historial de precios por producto (fechaVigencia, precio, costoUnidad, margenPct)
- `daily_summaries` — cache del resumen diario
- `daily_expenses` — gastos del día (concepto, monto, registradoPor)
- `daily_purchases` — compras/insumos (insumo, proveedor, cantidad, costo, registradoPor)
- `daily_payroll` — nómina del día (usuarioId, fecha, trabajo, jornada, salarioBase, estimulo, total)

**Removed**: All POS/FIFO/despacho tables (InventoryLots, Inventories, StockMovements, StockAdjustments, PurchaseInvoices, PurchaseInvoiceItems, Sales, SaleItems, Sessions, Orders, OrderItems, OrderPayments, DespachosRecibidos, DespachosEnviados, RendicionesProcesadas, InventorySnapshots, SyncLogs)

**Modified**: `products` → add `codigoCorto TEXT UNIQUE`; `users` → role data migration (existing POS roles mapped to SMS roles)

**Kept**: `categories`, `users`, `products`, `expenses` (reused for daily expenses), `app_settings`, `licenses`, `licencias_cliente`, `clientes`, `license_planes`

## Interfaces / Contracts

### SMS Payload (minified JSON, <160 chars)

```dart
class SmsPayload {
  final String type;      // PED | ACK | HEC | ENT | CAN
  final String orderId;   // R1-0712-007
  final String? client;
  final String? phone;
  final String? address;
  final String? reference;
  final List<Item> items; // [[code, qty]]
  final String? time;
  final String? payment;  // EF | TR | PD
  final double? amount;
  final String? motive;   // cancellation reason
}
```

### Order State Machine

```dart
/// Dos flujos:
/// Domicilio: REGISTRADO → EN_COCINA → HECHO → EN_CAMINO → ENTREGADO
/// Mesa:      NUEVO → EN_COCINA → HECHO → ENTREGADO_EN_MESA → PAGADO → CERRADO
enum OrderState {
  registrado,        // Redes crea pedido a domicilio
  enCocina,          // Cocina recibe PED o Mesero crea pedido de mesa
  hecho,             // Cocina termina de preparar
  enCamino,          // Domicilio sale a repartir
  entregado,         // Domicilio entrega (terminal, domicilio)
  entregadoEnMesa,   // Mesero entrega en mesa
  pagado,            // Mesa pagada
  cerrado,           // Pedido de mesa cerrado (terminal)
  cancelado;         // desde cualquier estado (terminal)

  static const validTransitions = {
    registrado: {enCocina, cancelado},
    enCocina: {hecho, cancelado},
    hecho: {enCamino, entregadoEnMesa, cancelado},
    enCamino: {entregado, cancelado},
    entregado: {},
    entregadoEnMesa: {pagado, cancelado},
    pagado: {cerrado, cancelado},
    cerrado: {},
    cancelado: {},
  };
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | SMS parser (JSON valid/invalid, pipe fallback, untrusted origin) | `SmsParser` parses each scenario, asserts fields, asserts discard |
| Unit | Order state machine (every transition, illegal transitions throw) | `OrderStateMachine` tests each `validTransitions` path + negative |
| Unit | SMS serialization (payload under 160 chars, short keys) | `SmsSerializer` tests minified JSON length |
| Unit | Daily close aggregation (sample orders → correct totals) | Mock Drift datasource, assert totals + 30/30/40 split |
| Unit | ACK timer (timeout → warning, reset on ACK) | Fake timers |
| Unit | Dedup (duplicate `id` ignored) | Double-insert scenario |
| Widget | Redes order form (create, add items, select client) | `flutter_test` + `ProviderScope` |
| Widget | Cocina queue (displays orders, mark HECHO) | `flutter_test` |
| Widget | Role gating (Redes cannot see Admin routes) | `GoRouter` redirect tests |
| Integration | Full PED→ACK→HEC→ENT flow (mocked SMS) | Mock `SmsService` |

## Migration / Rollout

1. **Schema v14 migration** in `onUpgrade`:
   - `from < 14`: drop 16 POS tables via `m.deleteTable()`, create 12 new SMS/restaurant tables (including `restaurant_tables`, `order_state_history`, `price_history`), add `codigoCorto` to products, seed food categories
   - Data migration: map `vendedor→redes`, `almacenero→cocina`, `super_admin→admin` in `users` table; log mapping
2. **First run**: seed food categories (`SÓLIDOS`, `LÍQUIDOS`, `POSTRES`); seed default mesas (1-10); any existing POS data (sales, orders, inventory) is lost — warn admin on first launch
3. **Rollback**: restore deleted directories from git, revert schema v14→v13, remove `telephony` from pubspec

## Delivery Strategy

This change exceeds 400 lines. Recommended delivery as **3 chained PRs**:
1. **PR 1**: Schema v14 + auth role migration + new Drift tables (no UI)
2. **PR 2**: SMS protocol + order state machine + Riverpod providers (no screens)
3. **PR 3**: All role-gated screens + daily close + router + delete POS modules

## Open Questions

- [ ] `telephony` package compatibility with Flutter 3.35/Dart 3.9 — verify pub.dev compatibility
- [ ] BroadcastReceiver permissions: `RECEIVE_SMS` + `READ_SMS` needed? Test on Android 13+
- [ ] Confirm existing POS data can be dropped (no business requirement to migrate sales history)
- [ ] Mesero role: shared device with Cocina? Local-only flow without SMS?
