# Client Management Specification

## Purpose

Define the restaurant client registry — a contact book of delivery customers separate from the existing `Clientes` table. Used by Redes to select or create clients when taking orders.

## Requirements

### Requirement: Client CRUD

The system MUST provide create, read, update, and soft-delete operations for restaurant clients. Each client record SHALL contain: name, phone, address, reference (optional), notes (optional), and registration date.

#### Scenario: Create new client from order form

- GIVEN the Redes user is filling an order and the phone number is not recognized
- WHEN the user taps "Create Client" in the order form
- THEN the system creates a new client with entered data and links it to the order

#### Scenario: Edit existing client

- GIVEN a client record exists with ID `CLI-001`
- WHEN the user updates the address field
- THEN the system persists the new address and keeps the original registration date

### Requirement: Client Search

The system MUST search clients by name or phone number using partial matching. Results MUST return matching records ordered by most recent first.

#### Scenario: Search by partial phone

- GIVEN clients with phones `53512345` and `53567890`
- WHEN the user types `535` in the client search field
- THEN both clients SHALL appear in results

#### Scenario: No match found

- GIVEN no client matches the search query
- WHEN the search completes
- THEN the system SHALL display a "Create new client" action

### Requirement: Separation from the Clientes Table

The `RestaurantClient` table MUST be a separate Drift table from the existing `Clientes` table. There SHALL be no foreign key relationship between them.

#### Scenario: Both tables coexist

- GIVEN the existing `Clientes` table has records
- WHEN querying restaurant clients
- THEN the system MUST return NO overlap with `Clientes` records

### Requirement: Reuse Across Orders

Once a client is registered, subsequent orders MAY select the existing client rather than re-entering data. The phone number SHOULD be unique per client.

#### Scenario: Repeat customer

- GIVEN client `Juan Perez` with phone `53512345` exists
- WHEN Redes starts a new order and selects Juan from client list
- THEN the order SHALL reference the existing client ID without duplicating data
