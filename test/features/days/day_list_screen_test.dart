import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/features/daily_close/domain/day_metrics.dart';
import 'package:etecsa/features/daily_close/presentation/providers/daily_close_datasource_provider.dart';
import 'package:etecsa/features/days/presentation/screens/day_list_screen.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

import 'day_test_support.dart';

// ---------------------------------------------------------------------------
// Lista de días (widget) — spec: day-management / "Day List with Counts and
// Status". Tarea 6.3 (RED):
//   - Cada fila muestra fecha, conteo de pedidos y estado abierto/cerrado.
//   - Un día solo aparece si tiene pedidos O cierre persistido (no se
//     fabrica el calendario). Sin ninguna actividad → estado vacío.
//   - Días ordenados del más reciente al más antiguo.
// ---------------------------------------------------------------------------

/// Monta [DayListScreen] con repositorio y cierres inyectados (en memoria).
Future<void> _pumpDayList(
  WidgetTester tester, {
  required List<RestaurantOrder> orders,
  required InMemoryCloseDatasource closes,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderRepositoryProvider.overrideWithValue(FakeOrderRepository(orders)),
        dailyCloseDatasourceProvider.overrideWithValue(closes),
      ],
      child: const MaterialApp(home: DayListScreen()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryCloseDatasource closes;

  setUp(() {
    // SideMenu (drawer de la pantalla) lee storage: mock evita canal real.
    FlutterSecureStorage.setMockInitialValues({});
    closes = InMemoryCloseDatasource(createTestDb());
  });

  tearDown(() async {
    await closes.db.close();
  });

  testWidgets('lista los días con conteo, estado y orden descendente', (
    tester,
  ) async {
    await closes.closeAsAdmin(
      fecha: '2026-10-01',
      metrics: const DayMetrics(ventas: 100, costoProduccion: 40),
    );

    await _pumpDayList(
      tester,
      orders: [
        seedOrder(id: 'A-1001-001', fechaIso: '2026-10-01'),
        seedOrder(id: 'B-1001-002', fechaIso: '2026-10-01'),
        seedOrder(id: 'C-1001-003', fechaIso: '2026-10-01'),
        seedOrder(id: 'D-1002-001', fechaIso: '2026-10-02'),
      ],
      closes: closes,
    );
    await tester.pumpAndSettle();

    // 2026-10-01: 3 pedidos, cerrada por cierre persistido.
    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('3 pedidos'), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);

    // 2026-10-02: 1 pedido, abierta (sin cierre).
    expect(find.text('2026-10-02'), findsOneWidget);
    expect(find.text('1 pedido'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);

    // Un día sin pedidos y sin cierre no se fabrica.
    expect(find.text('2026-10-03'), findsNothing);

    // Más reciente primero.
    expect(
      tester.getTopLeft(find.text('2026-10-02')).dy,
      lessThan(tester.getTopLeft(find.text('2026-10-01')).dy),
    );
  });

  testWidgets('un día cerrado sin pedidos aparece con conteo 0', (
    tester,
  ) async {
    await closes.closeAsAdmin(
      fecha: '2026-10-01',
      metrics: const DayMetrics(ventas: 0, costoProduccion: 0),
    );

    await _pumpDayList(
      tester,
      orders: [seedOrder(id: 'D-1002-001', fechaIso: '2026-10-02')],
      closes: closes,
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('0 pedidos'), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('sin pedidos ni cierres → estado vacío (sin filas)', (
    tester,
  ) async {
    await _pumpDayList(tester, orders: const [], closes: closes);
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('No hay días con actividad'), findsOneWidget);
  });
}
