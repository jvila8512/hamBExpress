# Proposal: Hamburguesas Express SMS Ordering — MVP

## Intent

Transform ExpresPOS into an SMS-based order system for Hamburguesas Express. Orders travel as structured SMS between role devices with ACK + dedup, eliminating manual transcription and reconciliation.

## Scope

### In Scope

1. Replace POS roles with SMS set (admin, redes, cocina, domicilio, mesero)
2. SMS protocol: JSON via `telephony`, ACK, dedup, timeout
3. Order states: REGISTRADO → EN_COCINA → HECHO → ENTREGADO/CANCELADO
4. Client registry (name, phone, address, reference)
5. Trusted contacts: phone whitelist per role
6. Products: add short code (CLE, LTE…)
7. Daily close: expenses, purchases, payroll, profit 30/30/40
8. Per-role UI (Redes form, Cocina queue, Domicilio list, Admin close)
9. Remove POS, inventory/FIFO, despachos, workers

### Out of Scope

Supervisión CC (F2), checksum (F2), multi-cocina (F2), Corte Mensual/Anual (F3), Historial Precios (F2), Import/Export, iOS.

## Capabilities

### New

- `sms-protocol`: payload types (`PED`,`ACK`,`HEC`,`ENT`,`CAN`), send, bg receive, parse, ACK timer, dedup
- `order-management`: CRUD, state machine, SMS binding
- `client-management`: restaurant client CRUD (separate from license clients)
- `trusted-contacts`: phone registry per role, SMS origin filter
- `role-flows`: role-gated UI shells
- `daily-close`: aggregation, profit 30/30/40, export

### Modified

- `auth`: role enum POS→SMS
- `products`: add `codigoCorto`, food categories

## Approach

One codebase, one Drift schema, role-gated UI via auth (same as current POS). New modules: `sms/`, `orders/`, `clients/`, `contacts/`, `daily_close/`. Adapt `auth/`, `products/`, `expenses/`. Remove `pos/`, `inventory/`, `despacho/`, `workers/`. Keep Riverpod + GoRouter. SMS via `telephony` + `BroadcastReceiver`.

## Affected Areas

| Area | Impact |
|------|--------|
| `lib/features/auth/` | Modified |
| `lib/features/products/` | Modified |
| `lib/features/categories/` | Reused |
| `lib/features/expenses/` | Reused + extend |
| `lib/features/{pos,inventory,despacho,workers}/` | Removed |
| `lib/features/{sms,orders,clients,contacts,daily_close}/` | New |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| SMS cost per segment | Medium | JSON minified; fallback `\|`-delimited |
| Android permission churn | Medium | Clear UX, graceful degradation |
| SMS truncation | Low | Discard unparseable, manual re-send |

## Rollback

1. Restore `pos/`, `inventory/`, `despacho/` from git
2. Revert auth roles + product schema
3. Drop new feature dirs
4. Remove `telephony` from pubspec

## Dependencies

`telephony` package; existing Drift + Riverpod + GoRouter.

## Success Criteria

- [ ] Redes sends SMS → Cocina auto-registers EN_COCINA
- [ ] Cocina marks HECHO → SMS → Domicilio sees EN_CAMINO
- [ ] Domicilio marks ENTREGADO → SMS → Redes sees closed
- [ ] ACK timeout → visual warning at 5 min
- [ ] Admin daily summary matches current Excel planilla
- [ ] POS/inventory/despacho screens removed
