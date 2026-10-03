# Delta for Products

## ADDED Requirements

### Requirement: Generic Product with Unit Price

The system MUST manage generic products identified by name with a single unit sale price. A product MUST be creatable and editable with only a name and a unit price — no short code, no category assignment, and no import step MAY be required for it to appear in the order catalog with its price.

#### Scenario: Create a product with name and price only

- GIVEN the Admin opens the product form
- WHEN the Admin enters name "Hamburguesa Sencilla" and unit price `450` with no code and no category
- THEN the product is saved
- AND it appears in the order catalog priced at `450`

#### Scenario: Product price is used on new order lines

- GIVEN a product "Hamburguesa Sencilla" with unit price `450`
- WHEN a user adds 3 units to an order
- THEN the line records quantity `3` and `precioUnitario = 450`
- AND the order total for that line is `1350`

## MODIFIED Requirements

### Requirement: Product Identification

The system MUST identify products by their internal UUID `id`. `id` is the identifier used in order items and everywhere the product is referenced. The `codigoCorto` column is no longer an identifier for any flow and MUST NOT be required by any screen or calculation.

(Previously: products were identified by both `id` and `codigoCorto`, with `codigoCorto` as the external SMS-protocol identifier.)

#### Scenario: Order lines reference the product id

- GIVEN a product with `id = 'p-1'`
- WHEN an order line is created for that product
- THEN the line references `p-1`
- AND no lookup by `codigoCorto` occurs

#### Scenario: Product works without a short code

- GIVEN a product whose `codigoCorto` is null
- WHEN the product is selected in the order form
- THEN the order line is created successfully with the product's unit price

## REMOVED Requirements

### Requirement: Short Code for SMS Protocol

(Reason: the JSON SMS payload protocol is deleted. Short codes exist only as the SMS `it` item identifier.)

### Requirement: Auto-Generate Short Codes

(Reason: short codes are deleted; auto-generating them has no consumer.)

### Requirement: Food-Specific Categories

(Reason: `SÓLIDOS`/`LÍQUIDOS`/`POSTRES` seeding exists only for the category-split SMS flow and the solid/liquid breakdown in the old daily close. Categories are no longer a product requirement; the categories screens are deleted.)

### Note on product import

The base `products` spec has no import requirement to remove — the proposal's "product import" deletion targets the `import_products_screen.dart` UI and its route, which are deleted with no delta entry needed.
