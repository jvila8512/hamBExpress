# Delta for Theme Preferences

## MODIFIED Requirements

### Requirement: Light default with role override (non-cocina)

The system MUST default to `ThemeMode.light`. `setDefaultThemeForRole` MUST be invoked after auth resolves and MUST apply light for both remaining roles, `admin` and `vendedor` — the role-default matrix is now exactly two entries and contains no dark entry. Per-role defaults apply only when the user has NOT explicitly saved a choice; a saved choice MUST always win.

(Previously: dark for `cocina` and light for `redes`, `admin`, `super_admin`, `domicilio`, `mesero` — five of those roles no longer exist.)

#### Scenario: First login defaults light for both roles

- GIVEN an `admin` or `vendedor` user with no saved theme
- WHEN the user logs in
- THEN theme is `light`

#### Scenario: No role defaults dark anymore

- GIVEN a user logs in with no saved theme
- WHEN `setDefaultThemeForRole` runs
- THEN the resulting mode is `light` for every role in the allowed set
- AND no code path assigns `dark` as a role default

#### Scenario: Saved choice still overrides

- GIVEN an `admin` user who previously saved `dark`
- WHEN the user logs in
- THEN theme is `dark`
- AND the role default of light does not overwrite it
