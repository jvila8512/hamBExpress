import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/core/database/app_database.dart'
    show AppDatabase, ProductsCompanion;
import 'package:etecsa/core/database/database_provider.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/orders/presentation/screens/order_form_screen.dart';

import '../../../days/day_test_support.dart';

// ---------------------------------------------------------------------------
// Order Form Screen (widget) — spec: order-management / "Order Day Field".
// Tarea 7.1 (RED):
//   - El formulario expone el día del pedido con default "hoy".
//   - Elegir un día en el picker y enviar → el pedido nace con ese día.
//   - El cliente elegido muestra nombre y teléfono (aprobación).
// ---------------------------------------------------------------------------

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Monta [OrderFormScreen] con repositorios fake y catálogo en BD memoria.
Future<void> _pumpForm(
  WidgetTester tester, {
  required OrderRepository orders,
  required FakeClientRepository clients,
  required AppDatabase db,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderRepositoryProvider.overrideWithValue(orders),
        clientRepositoryProvider.overrideWithValue(clients),
        databaseProvider.overrideWithValue(db),
      ],
      child: const MaterialApp(home: OrderFormScreen()),
    ),
  );
}

/// Busca al cliente por teléfono y lo deja seleccionado.
Future<void> _selectClient(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), '53512345');
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    // SideMenu (drawer de la pantalla) lee storage: mock evita canal real.
    FlutterSecureStorage.setMockInitialValues({});
    db = createTestDb();
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p1',
            name: 'Hamburguesa Sencilla',
            unitPrice: 450,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('muestra el día del pedido por defecto: hoy', (tester) async {
    final todayIso = _iso(DateTime.now());

    await _pumpForm(
      tester,
      orders: FakeOrderRepository(),
      clients: FakeClientRepository(),
      db: db,
    );
    await tester.pumpAndSettle();

    expect(find.text(todayIso), findsOneWidget);
  });

  testWidgets('elegir día en el picker → el pedido nace con ese día', (
    tester,
  ) async {
    final now = DateTime.now();
    // Día válido en cualquier mes y distinto de hoy (discriminante).
    final targetDay = now.day == 20 ? 5 : 20;
    final expectedIso = _iso(DateTime(now.year, now.month, targetDay));

    final repo = FakeOrderRepository();
    await _pumpForm(
      tester,
      orders: repo,
      clients: FakeClientRepository([
        const RestaurantClient(
          id: 'cli-juan',
          nombre: 'Juan Pérez',
          telefono: '53512345',
        ),
      ]),
      db: db,
    );
    await tester.pumpAndSettle();

    await _selectClient(tester);

    // Abrir el date picker desde el control del día.
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.calendar_month));
    await tester.pumpAndSettle();

    await tester.tap(find.text('$targetDay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // El control refleja el día elegido.
    expect(find.text(expectedIso), findsOneWidget);

    // Agregar el producto y enviar a cocina.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enviar a cocina'));
    await tester.pumpAndSettle();

    // Flushing del SnackBar de éxito (timer de 3s del sistema).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(repo.orders, hasLength(1));
    expect(repo.orders.single.fechaPedido, expectedIso);
  });

  testWidgets('el cliente elegido muestra nombre y teléfono', (tester) async {
    await _pumpForm(
      tester,
      orders: FakeOrderRepository(),
      clients: FakeClientRepository([
        const RestaurantClient(
          id: 'cli-juan',
          nombre: 'Juan Pérez',
          telefono: '53512345',
        ),
      ]),
      db: db,
    );
    await tester.pumpAndSettle();

    await _selectClient(tester);

    expect(find.text('Juan Pérez'), findsOneWidget);
    expect(find.text('53512345'), findsOneWidget);
  });
}
