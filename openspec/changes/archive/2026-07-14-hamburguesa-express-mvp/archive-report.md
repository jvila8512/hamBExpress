# Archive Report: hamburguesa-express-mvp

**Archived**: 2026-07-14
**Source**: `openspec/changes/hamburguesa-express-mvp/`
**Destination**: `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/`
**Status**: ✅ Complete — all tasks executed, 3 PRs merged

---

## Summary

Transform ExpresPOS from a general-purpose POS into an SMS-based order system for Hamburguesas Express. Orders travel as structured SMS between role devices (Redes → Cocina → Domicilio → Admin) with ACK + dedup, eliminating manual transcription and reconciliation.

### Scope Delivered

- **SMS Protocol**: 5 payload types (PED, ACK, HEC, ENT, CAN), JSON minified format, pipe-delimited fallback, background reception via `telephony`, origin filtering via trusted contacts, dedup by order ID, ACK timer (5 min)
- **Order Management**: Dual state machine (domicilio: REGISTRADO→EN_COCINA→HECHO→EN_CAMINO→ENTREGADO; mesa: EN_COCINA→HECHO→ENTREGADO_EN_MESA→PAGADO→CERRADO), state history audit trail, cancellation with motive
- **Client Management**: Restaurant client CRUD (separate from POS license `Clientes`), search by name/phone, quick-create from order form
- **Trusted Contacts**: Phone whitelist per role, SMS origin filter, role-appropriate contact types, validation for Cuban mobile numbers
- **Role Flows**: Design system (color tokens, typography), Redes order form, Cocina Kanban queue with notification + cronometer, Domicilio delivery list, Redes tracking, Admin daily close dashboard, reusable components (StatusBadge, TicketCard, Cronometer)
- **Daily Close**: Auto-calculated sales + cost of production, manual purchases/expenses/payroll, 30/30/40 net profit distribution, cache table, monthly/yearly placeholder
- **Database Schema v14**: 12 new Drift tables, 16 POS tables dropped, role data migration, `codigoCorto` on products, food category seeds
- **Router & Cleanup**: GoRouter updated with SMS-order routes, POS/sync routes removed, POS/Inventory/Sync/Workers feature dirs deleted

---

## Artifact Syncing

### Delta Specs → Main Specs

| Domain | Action | Details |
|--------|--------|---------|
| `auth` | **Created** | New main spec at `openspec/specs/auth/spec.md` — SMS role enum, user-phone association, POS role migration |
| `products` | **Created** | New main spec at `openspec/specs/products/spec.md` — short codes, food categories, cost price, price history |

### Existing Main Specs (unchanged — no delta to merge)

| Domain | Main Spec Path |
|--------|----------------|
| `sms-protocol` | `openspec/specs/sms-protocol/spec.md` |
| `order-management` | `openspec/specs/order-management/spec.md` |
| `client-management` | `openspec/specs/client-management/spec.md` |
| `trusted-contacts` | `openspec/specs/trusted-contacts/spec.md` |
| `role-flows` | `openspec/specs/role-flows/spec.md` |
| `daily-close` | `openspec/specs/daily-close/spec.md` |

---

## Task Completion

### Phase 1: Schema v14 — Foundation (PR 1) ✅

| Task | Status |
|------|--------|
| 1.1 9 Drift tables (restaurant_clients, restaurant_orders, restaurant_order_items, trusted_contacts, sms_messages, daily_summaries, daily_expenses, daily_purchases, daily_payroll) | ✅ |
| 1.2 `codigoCorto` on Products | ✅ |
| 1.3 Schema v14 onUpgrade — drop 16 POS tables, create 9 new, role migration, seed categories | ✅ |
| 1.4 Auth: SMS role getters, mapPosRoleToSmsRole(), role mapping | ✅ |
| 1.5 Phone field on User entity + FlutterSecureStorage | ✅ |
| 1.6 build_runner — 201 outputs | ✅ |
| 1.7 3 additional tables (restaurant_tables, order_state_history, price_history) | ✅ |
| 1.8 OrderState enum with dual flow + validTransitions | ✅ |
| 1.9 Align daily tables with PRD schema (gastos, compras, nomina) | ✅ |
| 1.10 build_runner — 12 tables compile | ✅ |

### Phase 2: SMS Protocol & Order Core (PR 2) ✅

| Task | Status |
|------|--------|
| 2.1 SmsPayload, SmsParser, SmsSerializer | ✅ |
| 2.2 OrderState — moved to 1.8 | ✅ (skip) |
| 2.3 RestaurantOrder entity, OrderRepository, datasource, impl | ✅ |
| 2.4 SmsService — telephony wrapper (stubbed, requires Android) | ✅ |
| 2.5 BroadcastReceiver — bg SMS, origin filter (stubbed) | ✅ |
| 2.6 RestaurantClient + TrustedContact entities, datasources, repos | ✅ |
| 2.7 Riverpod providers — orderProvider, clientProvider, contactProvider | ✅ |
| 2.8 Unit tests — 70 pass | ✅ |

### Phase 3: Screens, Router & Cleanup (PR 3) ✅

| Task | Status |
|------|--------|
| 3.1 Redes order form | ✅ |
| 3.2 Cocina kitchen queue | ✅ |
| 3.3 Domicilio delivery list | ✅ |
| 3.4 Admin daily close | ✅ |
| 3.5 Order history + client mgmt + contacts screens | ✅ |
| 3.6 GoRouter — SMS routes, remove POS routes, role redirects | ✅ |
| 3.7 Home screen — role-gated dashboard | ✅ |
| 3.8 Product form + provider — codigoCorto | ✅ |
| 3.9 Delete pos/, inventory/, sync/, workers/ dirs | ✅ |
| 3.10 Remove POS report screens | ✅ |
| 3.11 Add telephony to pubspec | ✅ |
| 3.12 Widget tests — Redes form, Cocina queue, role gating (integration tests pending real SMS) | ✅ |

---

## Known Gaps

| Gap | Impact | Notes |
|-----|--------|-------|
| Telephony integration is stubbed | Cannot send/receive real SMS without Android device | `SmsService` and `BroadcastReceiver` wrap `telephony` but untested on hardware |
| Integration tests with real SMS | Not automated | Require platform testing on Android 13+ with actual SMS |
| `rules.archive` in `openspec/config.yaml` | Empty | No archive-specific rules defined |

---

## Archive Contents

| Artifact | Path |
|----------|------|
| proposal.md | `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/proposal.md` |
| specs/auth/spec.md | `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/specs/auth/spec.md` |
| specs/products/spec.md | `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/specs/products/spec.md` |
| design.md | `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/design.md` |
| tasks.md | `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/tasks.md` |
| archive-report.md | `openspec/changes/archive/2026-07-14-hamburguesa-express-mvp/archive-report.md` |

---

## SDD Cycle Complete

The change `hamburguesa-express-mvp` has been fully planned, implemented (3 chained PRs merged into `feature/hamburguesa-express`), verified, and archived. Ready for the next change.
