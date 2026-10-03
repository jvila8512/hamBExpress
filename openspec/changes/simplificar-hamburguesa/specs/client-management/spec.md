# Delta for Client Management

**Decision: MODIFIED (wording only).** This capability is largely already implemented and is NOT reworked. All four requirements keep their exact behavior and `RestaurantClients` is preserved by the proposal's data strategy (keep `RestaurantClients` + `Products` + `Users`). The only change is removing references to the deleted `redes` role so the spec no longer names a role that does not exist. No client data is truncated.

## MODIFIED Requirements

### Requirement: Client CRUD

The system MUST provide create, read, update, and soft-delete operations for restaurant clients. Each client record SHALL contain: name, phone, address, reference (optional), notes (optional), and registration date.

(Previously: the creating actor was named as the Redes user — the `redes` role no longer exists.)

#### Scenario: Create new client from order form

- GIVEN the user is filling an order and the phone number is not recognized
- WHEN the user taps "Create Client" in the order form
- THEN the system creates a new client with entered data and links it to the order

#### Scenario: Edit existing client

- GIVEN a client record exists with ID `CLI-001`
- WHEN the user updates the address field
- THEN the system persists the new address and keeps the original registration date

### Requirement: Reuse Across Orders

Once a client is registered, subsequent orders MAY select the existing client rather than re-entering data. The phone number SHOULD be unique per client.

(Previously: the selecting actor was named as Redes.)

#### Scenario: Repeat customer

- GIVEN client `Juan Perez` with phone `53512345` exists
- WHEN the user starts a new order and selects Juan from the client list
- THEN the order SHALL reference the existing client ID without duplicating data

## Unchanged Requirements (kept as-is)

- Client Search (partial matching by name or phone, most recent first, "Create new client" fallback)
- Separation from the Clientes Table (`RestaurantClient` stays a separate Drift table with no FK to `Clientes`)
