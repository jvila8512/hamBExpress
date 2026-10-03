# Day Management Specification

## Purpose

Define the day-based navigation model: a list of days with order counts and open/closed status, an arbitrary editable order day, moving an order between days, and closing a day with ventas / ganancias / top clientes. This is a NEW capability (no prior main spec existed).

## ADDED Requirements

### Requirement: Day List with Counts and Status

The system MUST provide a navigable day list (route `/days`). Each listed day MUST show its date, the number of orders assigned to that day, and whether the day is open or closed. A day MUST appear in the list only when it has at least one order or a persisted close record. Days MUST be listed newest first. The day list MUST be reachable by both roles.

#### Scenario: Days show counts and closed status

- GIVEN day `2026-10-01` has 3 orders and a persisted close, day `2026-10-02` has 5 orders and no close, and day `2026-10-03` has no orders
- WHEN the user opens `/days`
- THEN `2026-10-01` is listed with count 3 and status closed
- AND `2026-10-02` is listed with count 5 and status open
- AND `2026-10-03` is not listed

#### Scenario: Empty day list

- GIVEN no order exists for any date and no close record exists
- WHEN the user opens `/days`
- THEN the list renders an empty state and shows no rows

### Requirement: Open a Day and View Its Orders

The system MUST allow opening a day from the day list and MUST display the orders of that day, grouped by day for analysis. Each order row MUST show the client name, the current state, and the order total.

#### Scenario: Open a day shows only its orders

- GIVEN day `2026-10-02` has orders `A-1002-001` and `A-1002-002`, and day `2026-10-01` has order `A-1001-001`
- WHEN the user taps the `2026-10-02` row
- THEN the screen lists `A-1002-001` and `A-1002-002`
- AND `A-1001-001` is NOT listed

### Requirement: Arbitrary Editable Order Day

Every order MUST carry a business day (`fechaPedido`) stored as an ISO date. The day MUST default to today when the order is created and MUST be editable by the user to any date (today, tomorrow, or any other day) at creation time and after creation. `fechaCreacion` MUST remain the creation timestamp used for audit and MUST NOT change when `fechaPedido` changes.

#### Scenario: New order defaults to today

- GIVEN today is `2026-10-03`
- WHEN the user creates an order without choosing a day
- THEN the order's `fechaPedido` is `2026-10-03`

#### Scenario: Day is editable and audit timestamp is preserved

- GIVEN an order created at `2026-10-03T10:00` with `fechaPedido = 2026-10-03`
- WHEN the user edits the order's day to `2026-10-04`
- THEN `fechaPedido` becomes `2026-10-04`
- AND `fechaCreacion` remains `2026-10-03T10:00`
- AND the day list shows one more order on `2026-10-04` and one less on `2026-10-03`

### Requirement: Move an Order Between Days

The system MUST allow moving an existing order to a different day. Moving MUST change only the order's `fechaPedido`; the order state, lines, client data, and totals MUST be preserved. Both the origin and destination day counts in the day list MUST update accordingly.

#### Scenario: Move an order from one day to another

- GIVEN day A has 2 orders and day B has 1 order
- WHEN the user moves one order from day A to day B
- THEN day A shows count 1 and day B shows count 2
- AND the moved order's state and line items are unchanged

### Requirement: Day Close Metrics

Closing a day MUST compute, for the selected date D, the following metrics over the orders whose `fechaPedido` equals D:
- **Ventas**: sum of order totals for orders in state `confirmado` or `recogido`. Orders in state `pedido` MUST be excluded.
- **Ganancias**: ventas minus cost of production, where cost of production is the sum of `quantity × costPrice` over the lines of the included orders.
- **Top clientes**: the included orders' clients ranked by total ventas descending.

The metrics computation MUST be a pure, day-parameterized function: the same input day MUST always produce the same output.

#### Scenario: Metrics computed for an arbitrary day

- GIVEN day `2026-10-01` has 2 orders in `recogido`, 1 order in `confirmado`, and 1 order in `pedido`
- WHEN the metrics function runs for `2026-10-01`
- THEN ventas includes the 3 `confirmado`/`recogido` orders
- AND the `pedido` order is excluded from ventas and ganancias
- AND ganancias equals ventas minus the included orders' production cost
- AND top clientes ranks the included orders' clients by ventas descending

#### Scenario: Day with no sales yields zeros

- GIVEN day `2026-09-01` has only orders in state `pedido`
- WHEN the metrics function runs for `2026-09-01`
- THEN ventas is 0, ganancias is 0, and top clientes is empty

### Requirement: Persisting a Day Close

Only `admin` MAY close a day; a close attempt performed by any other role MUST be rejected at the data layer, not merely hidden in the UI. Closing day D MUST persist a single close record keyed by the date D and MUST mark D as closed in the day list. Re-running the close for the same date MUST update the existing record rather than creating a second one. Opening a closed day MUST display its ventas, ganancias, and top clientes.

#### Scenario: Admin closes a day

- GIVEN an authenticated `admin` and day `2026-10-02` with orders
- WHEN the admin runs "Cerrar día" for `2026-10-02`
- THEN exactly one close record exists for `2026-10-02`
- AND the day list shows `2026-10-02` as closed
- AND opening `2026-10-02` displays ventas, ganancias, and top clientes

#### Scenario: Close is re-runnable and idempotent per date

- GIVEN day `2026-10-02` already has a close record
- WHEN the admin closes `2026-10-02` again after an order changed state
- THEN still exactly one close record exists for `2026-10-02`
- AND its values reflect the updated orders

#### Scenario: Vendedor cannot close a day

- GIVEN an authenticated `vendedor`
- WHEN the vendedor attempts to close day `2026-10-02`
- THEN the close is rejected and no close record is written
- AND the day remains open

### Requirement: Day Access by Role

Both roles MUST be able to read the day list and open a day. Order row actions (SMS, call, state) MUST remain available to both roles. Day closing MUST be restricted to `admin`.

#### Scenario: Vendedor reads the day list

- GIVEN an authenticated `vendedor`
- WHEN the vendedor navigates to `/days` and opens a day
- THEN the day list and the day's orders are rendered
- AND no close action is executed on their behalf
