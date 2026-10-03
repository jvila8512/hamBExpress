# Delta for Auth

## MODIFIED Requirements

### Requirement: SMS Role Enum

The system MUST support exactly two roles: `admin` and `vendedor`. No other role value may exist in the allowed role set. The login flow MUST remain unchanged.

(Previously: the system replaced the POS role enum with the SMS-specific roles `admin`, `redes`, `cocina`, `domicilio`, `mesero`.)

#### Scenario: Admin user authenticates

- GIVEN a user with role `admin` exists in the `users` table
- WHEN the user logs in with correct credentials
- THEN the system grants access with the admin UI shell (Usuarios, Configuración, products, day close, all order/day screens)

#### Scenario: Vendedor user authenticates

- GIVEN a user with role `vendedor` exists in the `users` table
- WHEN the user logs in with correct credentials
- THEN the system grants access with the vendedor UI shell (orders, clients, day list)

#### Scenario: Vendedor cannot reach admin screens

- GIVEN a user with role `vendedor` is authenticated
- WHEN attempting to navigate to `/workers`
- THEN the router redirects to the vendedor home route (`/`)
- AND no user data is rendered

### Requirement: User-Phone Association

The `Users` table MUST retain its optional `phone` field as user contact data. The field MUST NOT be required for login and MUST NOT be used for SMS routing — the role-to-role SMS network no longer exists. Client cell phone numbers are recorded on orders and clients, not on users.

(Previously: the phone field linked the user to their device number for SMS routing and incoming-SMS origin identification.)

#### Scenario: Admin edits a user's phone

- GIVEN an Admin is editing a user profile
- WHEN the Admin enters the phone number `53512345`
- THEN the system saves the phone number on the user record

#### Scenario: Login does not depend on phone

- GIVEN a user whose `phone` is null
- WHEN the user logs in with correct credentials
- THEN login succeeds and no SMS is composed or sent on the user's behalf

### Requirement: Migration from POS Roles

On first run after upgrade, the system MUST preserve every row in `Users` (username, password hash, full name, active flag) and MUST remap each legacy role value to exactly one of the two new roles: `super_admin` → `admin`, `admin` → `admin`, `redes` → `vendedor`, `cocina` → `vendedor`, `mesero` → `vendedor`, `domicilio` → `vendedor`, `almacenero` → `vendedor`, `vendedor` → `vendedor`. The remap MUST be total over that legacy set, MUST execute once, and MUST log the mapping. After the migration no stored role outside `{admin, vendedor}` may remain.

The migration MUST also update the Drift schema tests: `test/core/database/schema_v14_test.dart` (4 failures) and `test/core/database/schema_v14_additional_tables_test.dart` (3 failures) currently assert the pre-change schema. Those 7 failures are the PRE-EXISTING baseline (210 pass / 7 fail) and MUST NEVER be counted as regressions; they MUST be updated to assert the new schema version and the new/removed tables.

(Previously: existing POS users were mapped to SMS roles — `super_admin` → `admin`, `admin` → `admin`, `vendedor` → `redes`, `almacenero` → `cocina`.)

#### Scenario: Existing restaurant-role users remap to vendedor

- GIVEN a user with role `cocina` exists pre-migration
- WHEN the app starts with the new schema
- THEN the user's role becomes `vendedor`
- AND the user's username, password hash, and full name are unchanged

#### Scenario: Admin-role users are preserved

- GIVEN a user with role `super_admin` and a user with role `admin` exist pre-migration
- WHEN the app starts with the new schema
- THEN both users have role `admin`
- AND both rows still exist (no user is deleted)

#### Scenario: Remap covers every legacy value

- GIVEN users exist with each of `super_admin`, `admin`, `redes`, `cocina`, `mesero`, `domicilio`, `almacenero`, `vendedor`
- WHEN the migration runs
- THEN every user's role is `admin` or `vendedor`
- AND no stored role equals `super_admin`, `redes`, `cocina`, `mesero`, `domicilio`, or `almacenero`

## ADDED Requirements

### Requirement: Default Admin Seed

When the `Users` table contains no rows on first run, the system MUST create a default user with role `admin` so a fresh install can log in. The seed MUST NOT run when any user row already exists, and MUST NOT overwrite or reset an existing user's credentials.

#### Scenario: Fresh install seeds an admin

- GIVEN a fresh install with an empty `Users` table
- WHEN the app initializes the database
- THEN exactly one user exists with role `admin`
- AND that user can log in

#### Scenario: Existing installs are not re-seeded

- GIVEN the `Users` table already contains 4 users
- WHEN the app initializes the database
- THEN no additional user is created
- AND no existing user's password hash changes

### Requirement: Admin-Only Route Guard

The router MUST enforce admin-only access at the route level for `/workers`, `/settings`, and product-management routes: an authenticated non-admin MUST be redirected to `/` and the target screen MUST NOT render. Menu hiding alone is insufficient — deep links MUST be blocked. Order routes, client routes, and `/days` MUST remain reachable by `vendedor`.

(Previously: only `/workers` had a route-level guard; `/settings` and product routes relied on menu hiding.)

#### Scenario: Vendedor blocked from admin routes

- GIVEN an authenticated `vendedor`
- WHEN navigating directly to `/settings`
- THEN the router redirects to `/`
- AND the settings screen content is not rendered

#### Scenario: Vendedor keeps access to shared routes

- GIVEN an authenticated `vendedor`
- WHEN navigating directly to `/orders` and `/days`
- THEN the target screens render normally
- AND no redirect occurs

#### Scenario: Admin reaches admin routes

- GIVEN an authenticated `admin`
- WHEN navigating to `/workers` and `/settings`
- THEN both screens render with their full capabilities

## REMOVED Requirements

### Requirement: POS Role Enum Values Removed

(Reason: superseded by the two-role enum above. Its restriction on `vendedor` is reversed — `vendedor` is a valid role again — and the surviving part (no `super_admin`/`almacenero` stored after migration) is now stated in the migration requirement.)
