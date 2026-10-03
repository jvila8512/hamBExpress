# Delta for Role Flows

## MODIFIED Requirements

### Requirement: Design System — Color Tokens

The system MUST implement two complete color palettes (dark and light mode) using the exact hex values below. All roles MUST support both modes with a manual toggle (see Theme Default by Role). Color representation MUST be consistent across all screens and roles, and SHALL be derived ONLY from the brand tokens below — legacy cyan/purple values (`AppTheme.colorCeleste` / `colorMorado`) MUST NOT be used on any screen, in any role, after the migration completes.

#### Dark Mode Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` (Carbón) | `#241A14` | Screen background |
| `surface` (Plancha) | `#382A21` | Cards, panels |
| `text-primary` | `#F6ECDF` | Primary text |
| `text-secondary` | `#B0A196` | Secondary text, metadata |
| `accent` (Achiote) | `#D9531E` | Brand, primary buttons, "en cocina" state |
| `warning` (Mostaza) | `#E4A22E` | "Confirmed" state, time alerts |
| `success` (Mojo) | `#7C9A3B` | "Ready"/"Delivered" state |
| `danger` (Guayaba) | `#C2495B` | "Cancelled" state, errors, time exceeded |

#### Light Mode Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `bg` (Papel) | `#F6ECDF` | Screen background |
| `surface` | `#FFFFFF` | Cards, panels |
| `text-primary` | `#241A14` | Primary text |
| `text-secondary` | `#8A7A6C` | Secondary text, metadata |
| `accent` (Achiote) | `#D9531E` | Brand — does NOT change between modes |
| `warning` (Mostaza) | `#B97A1E` | Darkened for contrast on white |
| `success` (Mojo) | `#5E7A2A` | Darkened for contrast on white |
| `danger` (Guayaba) | `#A03347` | Darkened for contrast on white |

**RESOLVED DECISION (light bg):** `#F6ECDF` Papel cream IS the brand light background. "Light theme available" means it is functional and the default for non-cocina roles.

#### Scenario: Color tokens render correctly in both modes

- GIVEN the app is in dark mode
- WHEN rendering any screen
- THEN the background SHALL be `#241A14`, cards `#382A21`, text `#F6ECDF`, accent `#D9531E`
- WHEN the user toggles to light mode
- THEN the background SHALL be `#F6ECDF`, cards `#FFFFFF`, text `#241A14`, accent still `#D9531E`

#### Scenario: No legacy colors survive

- GIVEN the token migration is complete
- WHEN scanning `lib/` excluding `app_theme.dart`
- THEN zero references to `AppTheme.colorCeleste|AppTheme.colorMorado`
- AND splash/login/login-fields use tokens (Achiote, Papel/Carbón) not cyan

### Requirement: Theme Default by Role

Each role SHALL have a now-ENFORCED default theme: dark for Cocina, light for Redes/Domicilio/Admin/super_admin/Mesero. The default SHALL be applied automatically after login via `setDefaultThemeForRole` (wired from the theme provider — previously dead code), overriding the provider's static default. The user MUST be able to override the theme via Settings at any time, and the toggle SHALL persist across sessions (light / dark / system).

(Previously: the default was only "suggested" — the provider was hardcoded to dark and the role hook never ran.)

#### Scenario: Cocina defaults dark

- GIVEN a user with role `cocina` logs in for the first time (no saved preference)
- WHEN the home screen loads
- THEN the system SHALL apply dark theme (bg `#241A14`, surface `#382A21`)
- WHEN the user goes to Settings and toggles to light
- THEN the system SHALL switch to light theme immediately and persist the choice

#### Scenario: Non-cocina defaults light

- GIVEN a user with role `admin`, `super_admin`, `redes`, `domicilio` or `mesero` logs in with no saved preference
- WHEN the home screen loads
- THEN the system SHALL apply light theme (bg `#F6ECDF`, surfaces `#FFFFFF`)

## ADDED Requirements

### Requirement: Admin Navigation — Nuevo Pedido and Usuarios

The admin and super_admin side menus (`_adminMenuItems`, `_superAdminMenuItems` in side_menu.dart) MUST include `Nuevo Pedido` (→ `/orders/new`) and `Usuarios` (→ `/workers`). The admin dashboard (home_screen.dart) MUST expose a `Nuevo Pedido` action shortcut. The worker screen SHALL keep its existing capabilities (list users, create/edit admin/vendedor with plan-limit enforcement, reset password, activate/deactivate).

#### Scenario: Admin menu shows both entries

- GIVEN role `admin` or `super_admin` with the updated menu
- WHEN the user opens the side menu
- THEN `Nuevo Pedido` and `Usuarios` items are listed and navigate correctly
- WHEN the user taps `Nuevo Pedido` from the dashboard shortcut
- THEN the order form opens at `/orders/new`

### Requirement: `/workers` route with role guard

The router MUST register the `/workers` route (workers_screen.dart exists today without a route). Direct navigation to `/workers` MUST be allowed only for `admin` and `super_admin`; other roles MUST be redirected away (router-level redirect, not only menu hiding).

(Worker CRUD privileges remain as implemented: super_admin manages all visible users, admin manages vendedor/admin subset; capabilities preserved.)

#### Scenario: Admin reaches workers

- **GIVEN** an `admin` authenticated
- WHEN navigating to `/workers`
- THEN the WorkersScreen renders with its CRUD capabilities

#### Scenario: Non-admin redirected

- GIVEN `redes`, `cocina`, `domicilio`, or `mesero` authenticated
- WHEN navigating directly to `/workers`
- THEN the router redirects to the role's home (`/`)
- AND no user data is rendered

## REMOVED Requirements

- (none)