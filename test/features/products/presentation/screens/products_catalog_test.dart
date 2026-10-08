import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/core/database/app_database.dart'
    show ProductsCompanion;
import 'package:etecsa/core/database/database_provider.dart';
import 'package:etecsa/features/products/presentation/screens/product_form_screen.dart';
import 'package:etecsa/features/products/presentation/screens/products_screen.dart';

import '../../../days/day_test_support.dart';

// ---------------------------------------------------------------------------
// Products catalog (widget) — spec: products / "Generic Product with Unit
// Price" + "Product Identification". Tarea 7.2 (RED):
//   - El formulario no expone código corto ni categoría.
//   - Guardar solo con nombre + precio (sin costo, sin código) funciona y
//     la fila queda sin `codigoCorto`/`categoryId`.
//   - La lista muestra nombre + precio (verificación, llega en verde).
// ---------------------------------------------------------------------------

/// TextFormField que muestra [label] como `labelText`.
Finder _field(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // SideMenu (drawer de la lista) lee storage: mock evita canal real.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('el formulario no expone código ni categoría', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProductFormScreen())),
    );
    await tester.pumpAndSettle();

    // Nombre y precio: los únicos campos del genérico.
    expect(find.text('Nombre *'), findsOneWidget);
    expect(find.text('Precio de venta *'), findsOneWidget);

    // Ni código corto (SMS) ni código, ni categoría.
    expect(find.text('Código'), findsNothing);
    expect(find.text('Código Corto (SMS)'), findsNothing);
    expect(find.text('Categoría'), findsNothing);
  });

  testWidgets('guardar solo con nombre y precio → sin código ni categoría', (
    tester,
  ) async {
    final db = createTestDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Solo nombre + precio de venta: sin costo, sin código, sin categoría
    // (spec: "creatable ... with only a name and a unit price").
    await tester.enterText(_field('Nombre *'), 'Hamburguesa Sencilla');
    await tester.enterText(_field('Precio de venta *'), '450');

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Guardar'));
    await tester.pumpAndSettle();
    // Flushing de SnackBars del flujo de guardado (timers del sistema).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final rows = await db.select(db.products).get();
    expect(rows, hasLength(1));

    final row = rows.single;
    expect(row.name, 'Hamburguesa Sencilla');
    expect(row.unitPrice, 450);
    expect(row.costPrice, 0);
    expect(row.code, isNull);
    expect(row.codigoCorto, isNull);
    expect(row.categoryId, isNull);
  });

  testWidgets('la lista muestra nombre y precio, sin código ni categoría', (
    tester,
  ) async {
    final db = createTestDb();
    addTearDown(db.close);
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p1',
            name: 'Hamburguesa Sencilla',
            unitPrice: 450,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hamburguesa Sencilla'), findsOneWidget);
    expect(find.text('\$450.00'), findsOneWidget);
    expect(find.text('Código'), findsNothing);
    expect(find.text('Categoría'), findsNothing);
  });
}
