# Proposal: Simplificar Hamburguesa

## Intent

Adapt ExpresPOS from a multi-role restaurant POS into a WORKING app for selling hamburgers: two roles, day-based orders with 3 states, SMS/call/state row actions, and closable days with metrics. Restaurant-only features are deleted, not hidden.

## Scope

### In Scope

- Two roles only: `admin`, `vendedor`. `Users` table preserved (existing rows kept, legacy roles remapped) + default admin seeded when no users exist.
- Order header records: day (default today, EDITABLE), client name, cell phone, quantity; lines keep `{qty, precioUnitario}`.
- 3 states `pedido → confirmado → recogido`, enforced; state-button label changes per state.
- Per-row buttons: SMS (client's cell), call (dial), state (advance/inspect).
- Navigable day list with order counts; open a day; move an order between days; close a day showing ventas, ganancias, top de clientes.
- Generic products with unit price (existing price + cost kept).
- SMS via plain `sms:` composer URL to the client's cell number.

### Out of Scope

- Deleted: roles `super_admin/redes/cocina/mesero/domicilio`, expenses, trusted contacts, kitchen queue, delivery list, exports/import, help screen, categories screens, product import, mesas, JSON-payload SMS protocol + parser + broadcast receiver, `SmsMessages`/`OrderStateHistory` writes.
- Deferred: analytics beyond close-day metrics; multi-device sync.

## Capabilities

> Contract for sdd-spec. Main specs live in `openspec/specs/`.

### New Capabilities

- `day-management`: navigable list of days with order counts + open/closed status, arbitrary editable order day, moving an order between days, closing a day and showing ventas / ganancias / top de clientes.

### Modified Capabilities

- `auth`: two roles only; default admin user; `Users` preserved with legacy→new role remap; route guard extended beyond `/workers`.
- `role-flows`: admin/vendedor flows only; Redes/Cocina/Domicilio/Mesero UI requirements REMOVED; design tokens/typography/components kept; role-guard requirement becomes admin-only.
- `order-management`: 3-state machine replaces all 9 states + mesa/domicilio variants, SMS-triggered transitions, cancellation motive, payment-method SMS; transition validated in `updateOrderState`; add day field and the 3 row actions.
- `products`: generic products with unit price; REMOVE short-code, food-specific categories, and import requirements.
- `daily-close`: parameterized by ANY day (today-only hard-wiring removed), adds top de clientes, persists close (first real use of `DailySummaries`); manual Gastos/Compras/Nómina tabs REMOVED.
- `sms-protocol`: REMOVE all requirements (replaced by `sms:` intent under order row actions).
- `trusted-contacts`: REMOVE all requirements.
- `theme-preferences`: role-default matrix reduces to admin/vendedor (both light).

## Approach

| Decision | Recommendation | Tradeoff |
|----------|----------------|----------|
| **Data strategy** | Single Drift migration v14→v15: keep ALL `Users` rows (remap `super_admin/admin→admin`, `redes/cocina/mesero/domicilio→vendedor`), seed default admin if table empty; keep `RestaurantClients` + `Products` rows; recreate order tables and **truncate legacy order/order-item data**; drop restaurant-only tables. | Fresh install (delete DB) is simplest but loses `Users` → violates requirement. Keeping legacy orders forces a 9→3 state mapping over unmappable in-flight data. |
| **daily_close compute** | KEEP + adapt `daily_close_provider.dart:214-440`: extract a pure day-parameterized function (ventas, costo, ganancias, top productos; add top clientes), delete the 4 manual tabs. | Rewriting from scratch is cleaner but reimplements working cost/profit math and risks regressions for no user-visible gain. |
| **3-state model** | Replace enum with `pedido/confirmado/recogido`; enforce via `canTransitionTo` inside `updateOrderState` (TDD); unknown/legacy `estado` defensively maps to `pedido`. | Order rows are truncated, so mapping is belt-and-suspenders — cheap insurance, no real cost. |
| **Editable day** | New `fechaPedido` (ISO date, default today), writable by `updateOrder()`; keep `fechaCreacion` as creation audit. | Overloading `fechaCreacion` saves a column but destroys the audit timestamp. |
| **Day navigation** | New `/days` screen (day, count, closed flag); "Cerrar día" computes metrics, writes `DailySummaries`, shows ventas/ganancias/top clientes. | Wiring the never-used `DailySummaries` table beats adding a 9th dead table. |
| **Row buttons** | `sms:<cell>?body=…` and `tel:<cell>` via `launchUrl`; state button opens advance/inspect sheet — labels: `Confirmar` (pedido) → `Marcar recogido` (confirmado) → `Recogido` (terminal, inspect only). | `sms:` opens the composer (user taps send) — no silent send; that IS the requested behavior. |
| **Roles & guards** | `admin`: users (`/workers`), settings, products, day close, all order/day screens. `vendedor`: orders, clients, day list (read) + own order actions. Router redirects non-admin from `/workers` and `/settings`. | Menu-hiding alone leaves deep links open (today's state) — router-level redirect is the fix. |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/core/database/app_database.dart` | Modified | v15 schema: `fechaPedido`, 3-state `estado`, drop legacy tables |
| `lib/features/orders/` | Modified | entity/enum/datasource, row actions, day field, state validation |
| `lib/features/daily_close/` | Modified | day-parameterized metrics, top clientes, drop manual tabs |
| `lib/features/products/` | Modified | delete categories/import screens + routes |
| `lib/features/sms/`, `lib/features/help/`, expenses/trusted-contacts | Removed | JSON protocol, parser, receiver, dead screens |
| `lib/config/router/app_router.dart`, `home_screen`, `side_menu` | Modified | `/days` route, admin guards, 2-role menus |
| `test/` | Modified | new TDD specs; `schema_v14*` tests updated for v15 |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Schema change collides with the 7 pre-existing `schema_v14*` failures | High | Never counted as regressions; update schema tests for v15 explicitly |
| Truncating orders destroys real client data | Medium | Explicit, client-approved data loss; take a manual DB backup before rollout |
| Role remap leaves a user with no menu | Low | Remap is total (every legacy value → exactly one new role) + default admin seed |
| Slow machine, full suite not runnable | Medium | Run `flutter test` only at phase gates; no `flutter build` |

## Rollback Plan

Revert the change branch (conventional commits keep the history clean). v15 migration is forward-only, so rollback restores code only: ship a follow-up migration if schema must be reversed. Order-row truncation is unrecoverable → pre-rollout DB backup is mandatory.

## Dependencies

- Drift codegen: `dart run build_runner build` after schema change.
- Device must have a default SMS/dial app for `sms:`/`tel:` intents.

## Success Criteria

- [ ] `flutter test`: ≥210 pass, no NEW failures (the 7 `schema_v14*` are pre-existing).
- [ ] Fresh install seeds a default admin; upgraded install keeps all existing `Users`.
- [ ] Create order for today/tomorrow/any day; day list shows counts; move order between days.
- [ ] Order advances only `pedido → confirmado → recogido`; button label matches state (test: invalid transition rejected).
- [ ] Closing a day shows ventas, ganancias, top de clientes; rows expose SMS/call/state buttons.
- [ ] `rg`-style scan finds zero references to deleted roles, JSON SMS parser, or dead routes.

## Open Question (do not guess)

- Client said: *"en productos borrar las reglas, analida"* — ambiguous. Possible readings: "borrar las reglas, análisis" (delete rules + analysis?), or a mistyped "categorías". **Confirm with client before spec'ing the products deletions.**
