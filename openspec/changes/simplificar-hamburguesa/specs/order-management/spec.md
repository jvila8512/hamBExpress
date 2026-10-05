# Delta for Order Management

## MODIFIED Requirements

### Requirement: Order Creation and ID Format

The system MUST capture, on the order header: the business day (`fechaPedido`, default today, editable), the client name, the client cell phone, and one or more line items each holding `{quantity, precioUnitario}`. The system MUST generate a unique order ID per device using the format `{origen}{seq}-{MMDD}-{seq}`, e.g. `A1-1003-007`. The origin prefix MUST identify the creating role: `A` for `admin`, `V` for `vendedor`. A newly created order MUST start in state `pedido`.

(Previously: the order form captured Redes/Cocina/Domicilio/Admin client data and items, and the origin prefix identified the role device `R`/`C`/`D`/`A`; the initial state was `REGISTRADO`.)

#### Scenario: Vendedor creates an order for another day

- GIVEN the vendedor fills the order form with client name "Juan Perez", cell `53512345`, two line items, and selects tomorrow as the day
- WHEN the vendedor confirms the order
- THEN the system assigns an ID starting with `V`, sets state `pedido`, and persists the order
- AND the order row displays the client name and cell phone

#### Scenario: Order without explicit day defaults to today

- GIVEN today is `2026-10-03`
- WHEN an order is created without selecting a day
- THEN `fechaPedido` is `2026-10-03`

### Requirement: Order Day Field

The order record MUST persist `fechaPedido` as an ISO calendar date, separate from `fechaCreacion`. `fechaPedido` MUST default to today, MUST be writable through `updateOrder()`, and MUST NOT alter `fechaCreacion`.

(Previously: no business-day field existed — only the `fechaCreacion` creation timestamp.)

#### Scenario: Day is writable through updateOrder

- GIVEN an order with `fechaPedido = 2026-10-03`
- WHEN `updateOrder()` is called with `fechaPedido = 2026-10-05`
- THEN the stored `fechaPedido` is `2026-10-05`
- AND `fechaCreacion` is unchanged

## ADDED Requirements

### Requirement: Legacy Order Data Migration

On upgrade, the system MUST truncate all legacy order and order-item rows (both the POS order tables and the restaurant order tables) — keeping legacy 9-state orders would force an unmappable state mapping. The same migration MUST drop the tables that back the deleted features (trusted contacts, SMS log, state-history audit, restaurant table registry, and the manual gastos/compras/nomina tables) while preserving every row in `Users`, `RestaurantClients`, and `Products`.

#### Scenario: Legacy orders are truncated

- GIVEN the pre-upgrade database contains restaurant orders in `EN_COCINA` and POS orders
- WHEN the upgrade migration runs
- THEN zero legacy order rows and zero legacy order-item rows remain

#### Scenario: Preserved tables keep their rows

- GIVEN the pre-upgrade database contains 4 users, 12 restaurant clients, and 30 products
- WHEN the upgrade migration runs
- THEN users, clients, and products counts are unchanged (roles are remapped per the `auth` migration requirement)
- AND no `TrustedContacts`, `SmsMessages`, `OrderStateHistory`, `RestaurantTables`, `DailyExpenses`, `DailyPurchases`, or `DailyPayroll` table exists afterwards

### Requirement: Three-State Order Machine

Orders MUST follow exactly one state machine: `pedido → confirmado → recogido`. `recogido` is terminal. No other state and no other transition MAY exist — there is no cancelled state and no mesa/domicilio variant. The transition MUST be validated inside `updateOrderState` via `canTransitionTo`; a rejected transition MUST leave the stored state unchanged and MUST surface an error to the caller. State transitions MUST be triggered only by explicit user action — never by SMS receipt, since no background SMS receiver exists.

#### Scenario: Valid advance from pedido to confirmado

- GIVEN an order in state `pedido`
- WHEN the user taps the state button and confirms
- THEN `updateOrderState` is called with `confirmado`
- AND the stored state becomes `confirmado`

#### Scenario: Invalid transition is rejected

- GIVEN an order in state `pedido`
- WHEN `updateOrderState` is called with `recogido`
- THEN the call fails with a transition error
- AND the stored state remains `pedido`

#### Scenario: Terminal state cannot be left

- GIVEN an order in state `recogido`
- WHEN `updateOrderState` is called with `pedido` or `confirmado`
- THEN the call fails
- AND the stored state remains `recogido`

#### Scenario: Unknown or legacy state maps to pedido

- GIVEN an order row whose stored `estado` is an unrecognised value (e.g. `EN_COCINA`)
- WHEN the order is read
- THEN it is presented as `pedido`
- AND the three-state button label for `pedido` is shown

#### Scenario: No SMS-driven transitions

- GIVEN the app contains no background SMS receiver or SMS payload parser
- WHEN scanning `lib/` for state changes caused by SMS receipt
- THEN zero matches are found

### Requirement: Order Row Actions

Every order row MUST expose exactly three actions:
1. **SMS button** — MUST open the device's default SMS composer via an `sms:<cell>?body=…` intent addressed to the order's client cell phone, with a plain-text order summary as the body. The app MUST NOT send the message silently; the user taps send in the composer.
2. **Call button** — MUST open the dialer via a `tel:<cell>` intent with the order's client cell phone pre-filled.
3. **State button** — MUST show a label derived from the current state: `Confirmar` for `pedido`, `Marcar recogido` for `confirmado`, `Recogido` for `recogido`. Tapping it on `pedido` advances to `confirmado`; on `confirmado` advances to `recogido`; on `recogido` it only inspects the order and MUST NOT change state.

#### Scenario: State button label follows state

- GIVEN an order in state `pedido`
- WHEN the order row renders
- THEN the state button label is `Confirmar`
- GIVEN the order advances to `confirmado`
- WHEN the row re-renders
- THEN the label is `Marcar recogido`
- GIVEN the order reaches `recogido`
- WHEN the row re-renders
- THEN the label is `Recogido` and tapping it changes nothing

#### Scenario: SMS button opens the composer

- GIVEN an order for client cell `53512345`
- WHEN the user taps the SMS button
- THEN an `sms:53512345` intent is launched with the order summary body
- AND no message is sent without user confirmation

#### Scenario: Call button opens the dialer

- GIVEN an order for client cell `53512345`
- WHEN the user taps the call button
- THEN a `tel:53512345` intent is launched

## REMOVED Requirements

### Requirement: Order State Machine (Domicilio)

(Reason: the `domicilio` flow `REGISTRADO → EN_COCINA → HECHO → EN_CAMINO → ENTREGADO` and its SMS-triggered transitions are deleted; replaced by the three-state machine.)

### Requirement: Order State Machine (Mesa)

(Reason: the `mesero` flow `NUEVO → EN_COCINA → HECHO → ENTREGADO_EN_MESA → PAGADO → CERRADO` is deleted along with the `mesero` role.)

### Requirement: Order Types and Table Support

(Reason: `DOMICILIO`/`MESA` order types, `mesaId`, and the `restaurant_tables` registry are deleted. Orders have no type variant — only the editable day.)

### Requirement: State History Audit Trail

(Reason: `order_state_history` writes are deleted per the proposal; `fechaCreacion` remains the only audit timestamp.)

### Requirement: Cancellation with Reason

(Reason: cancellation and the `motivoCancelacion` motive field are deleted — the state machine has exactly three states with no cancelled state.)

### Requirement: Payment Method Tracking

(Reason: the payment-method field on the order and the `ENT`-SMS payment payload (`pg`/`mt`) are deleted. The proposal's order header is day + client name + cell phone + quantity/lines, and the day close reports ventas/ganancias with no EF/TR breakdown.)
