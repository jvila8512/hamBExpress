# Delta for Daily Close

## MODIFIED Requirements

### Requirement: Auto-Calculated Sales Block

The system MUST calculate sales for an ARBITRARY selected day D (not only today) by summing line subtotals of the orders whose `fechaPedido` equals D and whose state is `confirmado` or `recogido`. Each product's subtotal = quantity × `precioUnitario` recorded on the line. Per-product subtotals MUST be summed into Total Sales. The solid/liquid category split is gone — there is no category breakdown.

(Previously: totals were computed only for the current day's `ENTREGADO` orders, split into solid and liquid categories.)

#### Scenario: Sales computed for a chosen past day

- GIVEN day `2026-10-01` has 3 orders in `recogido` and 1 order in `confirmado`
- WHEN the Admin opens the daily close for `2026-10-01`
- THEN Total Sales equals the sum of the subtotals of those 4 orders
- AND a per-product breakdown is shown with no category split

#### Scenario: Orders outside the day or state are excluded

- GIVEN day `2026-10-01` has 1 order in `pedido` and 1 order assigned to `2026-10-02`
- WHEN the close for `2026-10-01` is computed
- THEN neither order contributes to Total Sales

### Requirement: Cost of Production

The system MUST calculate cost of production for the selected day D as the sum of `quantity × costPrice` over the lines of the orders included in that day's sales. This MUST auto-populate when the daily close for D is opened.

(Previously: cost was computed only from today's delivered orders.)

#### Scenario: Cost reflects the selected day's sold quantities

- GIVEN day `2026-10-01` sold 10 units of a product whose `costPrice` is `2500`
- WHEN cost of production is calculated for `2026-10-01`
- THEN it SHALL be `10 × 2500 = 25000`

### Requirement: Derived Profit Calculations

The system MUST compute, for the selected day: **Ganancias = Total Sales − Cost of Production**, and MUST apply the 30/30/40 distribution to Ganancias (30% Yurdenis, 30% Mildrey, 40% Reinversión). Purchases, expenses, and payroll MUST NOT appear in the formula because those manual blocks are removed.

(Previously: Utilidad Neta = Total Sales − Cost of Production − Total Expenses − Total Purchases − Payroll, then 30/30/40 on that figure.)

#### Scenario: Profit distribution display

- GIVEN a day with Total Sales `60,000` and Cost of Production `50,000`
- WHEN the daily close calculates distribution
- THEN Ganancias is `10,000`
- AND it SHALL display: Yurdenis 3,000 CUP (30%), Mildrey 3,000 CUP (30%), Reinversión 4,000 CUP (40%)

#### Scenario: Removed cost terms never appear

- GIVEN the daily close for any day is rendered
- WHEN inspecting the profit block
- THEN no Gastos, Compras, or Nómina line item is shown

### Requirement: Resumen del Día Cache Table

The system MUST persist the computed daily close to the `DailySummaries` table keyed by its ISO date string, so a closed day is identified by the existence of its row. Re-running the close for the same date MUST update the existing row rather than creating a second one, and MUST be the first real use of that table.

(Previously: the close was cached in a `resumen_dia` table keyed by date.)

#### Scenario: Re-run daily close

- GIVEN the daily close was already persisted for `2026-10-02`
- WHEN an order on `2026-10-02` changes state and the close runs again
- THEN the single `DailySummaries` row for `2026-10-02` is updated with the new values

#### Scenario: Persisted row marks the day closed

- GIVEN no `DailySummaries` row exists for `2026-10-02`
- WHEN the close for `2026-10-02` runs
- THEN one row keyed `2026-10-02` exists
- AND the day list reports `2026-10-02` as closed

## ADDED Requirements

### Requirement: Top de Clientes Block

The daily close for the selected day MUST display a **Top de clientes** block listing the day's clients ranked by total ventas descending, with each client's amount. The block MUST be computed for the same set of orders used by Total Sales (`confirmado` + `recogido` on that day) and MUST show an empty state when that set is empty.

#### Scenario: Top clients ranked by ventas

- GIVEN day `2026-10-02` has client "Maria" with ventas `9,000` and client "Juan" with ventas `12,000`
- WHEN the Admin opens the close for `2026-10-02`
- THEN Juan is listed first with `12,000` and Maria second with `9,000`

#### Scenario: Empty top clients

- GIVEN day `2026-10-02` has no orders in `confirmado` or `recogido`
- WHEN the close for `2026-10-02` is displayed
- THEN the Top de clientes block shows an empty state

### Requirement: Close Is Admin-Only

Running the daily close MUST be restricted to `admin`. A close invocation from `vendedor` MUST be rejected before any `DailySummaries` write.

#### Scenario: Vendedor close rejected

- GIVEN an authenticated `vendedor`
- WHEN a close is invoked for `2026-10-02`
- THEN the invocation is rejected
- AND no `DailySummaries` row is written for `2026-10-02`

## REMOVED Requirements

### Requirement: Manual Input Blocks

(Reason: the Gastos, Compras, and Nómina tabs and their `gastos`/`compras`/`nomina` writes are deleted. Only the Resumen content survives, reworked as the day close.)

## Unchanged Requirements (kept as-is)

- Monthly/Yearly Aggregation (Placeholder) — the F3 placeholder is not mentioned by the proposal and stays untouched.
