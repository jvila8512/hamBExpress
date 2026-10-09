# Delta for Role Flows

## MODIFIED Requirements

### Requirement: Theme Default by Role

Each remaining role SHALL have an ENFORCED default theme: light for `admin` and light for `vendedor`. The default SHALL be applied automatically after login via `setDefaultThemeForRole`, overriding the provider's static default. The user MUST be able to override the theme via Settings at any time, and the toggle SHALL persist across sessions (light / dark / system).

(Previously: dark for `cocina`, light for `redes`/`domicilio`/`admin`/`super_admin`/`mesero` — `cocina` no longer exists.)

#### Scenario: Vendedor defaults light

- GIVEN a `vendedor` user with no saved theme logs in for the first time
- WHEN the home screen loads
- THEN the system SHALL apply the light theme (bg `#F6ECDF`, surfaces `#FFFFFF`)

#### Scenario: Admin defaults light and can override

- GIVEN an `admin` user with no saved theme logs in
- WHEN the home screen loads
- THEN the system SHALL apply the light theme
- WHEN the user toggles to dark in Settings
- THEN the system SHALL switch to dark immediately and persist the choice across restarts

### Requirement: Reusable Components

The system MUST provide these reusable widgets:

1. **StatusBadge**: colored pill mapped to the three order states using the palette — `pedido` → Achiote `#D9531E`, `confirmado` → Mostaza `#E4A22E`, `recogido` → Mojo `#7C9A3B`
2. **TicketCard**: card with a perforated/dotted border at the top, used for order rows and the cart summary

(Previously: StatusBadge mapped 9 restaurant states, and a Cronometer widget was required.)

#### Scenario: StatusBadge renders the three states

- GIVEN an order in state `pedido`
- WHEN its StatusBadge renders
- THEN the pill uses Achiote `#D9531E`
- GIVEN an order in state `confirmado`
- WHEN its StatusBadge renders
- THEN the pill uses Mostaza `#E4A22E`
- GIVEN an order in state `recogido`
- WHEN its StatusBadge renders
- THEN the pill uses Mojo `#7C9A3B`

#### Scenario: TicketCard renders correctly

- GIVEN an order row in a day view
- WHEN rendered
- THEN the card SHALL have a dotted top border with circle perforations (visual ticket style)
- AND the StatusBadge SHALL show the current state in the correct color

### Requirement: Single Navigation — Productos, Clientes and Días

The side menu MUST contain exactly three entries, identical for every role: `Productos` (→ `/products`), `Clientes` (→ `/clients`) and `Días` (→ `/days`). Per-role menu variants MUST NOT exist. `Productos` MUST be reachable by both `admin` and `vendedor` (authenticated). The dashboard MUST expose a `Nuevo Pedido` action shortcut to `/orders/new`. The worker screen SHALL keep its existing capabilities (list users, create/edit admin/vendedor, reset password, activate/deactivate).

(Previously: two per-role menu variants existed — `_adminMenuItems` [Usuarios, Configuración] for `admin` and `_vendedorMenuItems` [Pedidos, Clientes, Días] for `vendedor`.)

#### Scenario: Side menu shows the three MVP entries

- GIVEN any authenticated role
- WHEN the user opens the side menu
- THEN `Productos`, `Clientes` and `Días` items are listed and navigate correctly
- AND no per-role menu variant is rendered

#### Scenario: Vendedor reaches products

- GIVEN a `vendedor` authenticated
- WHEN navigating to `/products`
- THEN the ProductsScreen renders

#### Scenario: Nuevo Pedido shortcut

- GIVEN an authenticated user on the dashboard
- WHEN the user taps `Nuevo Pedido`
- THEN the order form opens at `/orders/new`

### Requirement: `/workers` route with role guard

The router MUST register the `/workers` route and MUST allow it only for `admin`; `vendedor` MUST be redirected away at router level (not only menu hiding), and no user data may render.

(Worker CRUD capabilities are preserved: with `super_admin` deleted, `admin` manages the visible user list — create/edit `admin` and `vendedor` users, reset password, activate/deactivate.)

(Previously: access was allowed for `admin` and `super_admin`; other roles were the restaurant roles `redes`, `cocina`, `domicilio`, `mesero`.)

#### Scenario: Admin reaches workers

- GIVEN an `admin` authenticated
- WHEN navigating to `/workers`
- THEN the WorkersScreen renders with its CRUD capabilities

#### Scenario: Vendedor redirected

- GIVEN a `vendedor` authenticated
- WHEN navigating directly to `/workers`
- THEN the router redirects to `/`
- AND no user data is rendered

## ADDED Requirements

### Requirement: Vendedor Navigation

The `vendedor` side menu MUST be identical to the admin side menu (`Productos`, `Clientes`, `Días`). The vendedor dashboard MUST expose the same order row actions as admin on the orders they can open. `Usuarios` and `Configuración` are NOT side-menu entries for any role; they remain admin-only routes reachable from the admin dashboard.

#### Scenario: Vendedor menu contents

- GIVEN role `vendedor`
- WHEN the user opens the side menu
- THEN Productos, Clientes, and Días entries are listed
- AND neither `Usuarios` nor `Configuración` is listed

#### Scenario: Vendedor deep link to admin entry is blocked

- GIVEN role `vendedor`
- WHEN the user navigates directly to `/workers` or `/settings`
- THEN the router redirects to `/`

## REMOVED Requirements

### Requirement: Redes UI — New Order Form

(Reason: the Redes-specific form with "Enviar a cocina", `PED` SMS send, and waiting-for-ACK status is deleted. Order creation is now a single generic form — day, client name, cell phone, line items — specified in `order-management`.)

### Requirement: Cocina UI — Order Queue with Notification

(Reason: the `cocina` role, kitchen Kanban queue, repeating notification, cronometer, and `HEC` SMS are deleted.)

### Requirement: Domicilio UI — Delivery View

(Reason: the `domicilio` role, delivery list, payment-method selector, and `ENT` SMS are deleted. The `tel:` call button survives as an order row action in `order-management`.)

### Requirement: Redes UI — Order Tracking

(Reason: SMS-driven live tracking across devices is deleted. Orders are analyzed by opening a day in the day-management day list.)

### Requirement: Admin UI — Daily Close Dashboard

(Reason: EF/TR breakdown and operational indicators (kitchen time, delivery time, cancelled orders, unconfirmed payment) depend on deleted states and payment-method SMS. The day close content — ventas, ganancias, top clientes — is specified in `daily-close` and `day-management`.)

## Unchanged Requirements (kept as-is)

- Design System — Color Tokens (palette and legacy cyan/purple prohibition)
- Design System — Typography (Bungee / DM Sans / JetBrains Mono)
