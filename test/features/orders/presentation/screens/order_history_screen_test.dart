import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/orders/presentation/screens/order_history_screen.dart';

import '../../../days/day_test_support.dart';

// ---------------------------------------------------------------------------
// Order History Screen (widget) — spec: order-management / "Order Row
// Display". Tarea 7.1 (RED):
//   - La fila del historial muestra nombre y teléfono del cliente
//     resueltos por `clienteId` (hoy solo imprime el UUID crudo).
//   - Filtro de estado de tres estados (pedido/confirmado/recogido).
// ---------------------------------------------------------------------------

/// Monta [OrderHistoryScreen] con pedidos y clientes fake (en memoria).
Future<void> _pumpHistory(
  WidgetTester tester, {
  required List<RestaurantOrder> orders,
  List<RestaurantClient> clients = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        orderRepositoryProvider.overrideWithValue(FakeOrderRepository(orders)),
        clientRepositoryProvider
            .overrideWithValue(FakeClientRepository(clients)),
      ],
      child: const MaterialApp(home: OrderHistoryScreen()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // SideMenu (drawer de la pantalla) lee storage: mock evita canal real.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('la fila muestra nombre y teléfono del cliente (no el UUID)', (
    tester,
  ) async {
    await _pumpHistory(
      tester,
      orders: [
        seedOrder(
          id: 'A-1008-001',
          fechaIso: '2026-10-08',
          clienteId: 'cli-juan',
          estado: OrderState.pedido,
        ),
      ],
      clients: [
        const RestaurantClient(
          id: 'cli-juan',
          nombre: 'Juan Pérez',
          telefono: '53512345',
        ),
      ],
    );
    await tester.pumpAndSettle();

    // Nombre resuelto desde `clienteId`.
    expect(find.text('Cliente: Juan Pérez'), findsOneWidget);

    // Teléfono visible en la fila (además de habilitar SMS/llamada).
    expect(find.text('53512345'), findsOneWidget);

    // El UUID crudo no se expone al usuario.
    expect(find.text('Cliente: cli-juan'), findsNothing);
  });

  testWidgets('filtro de estado: tres opciones y filtra la lista', (
    tester,
  ) async {
    await _pumpHistory(
      tester,
      orders: [
        seedOrder(
          id: 'A-1008-001',
          fechaIso: '2026-10-08',
          clienteId: 'cli-juan',
          estado: OrderState.pedido,
        ),
        seedOrder(
          id: 'A-1008-002',
          fechaIso: '2026-10-08',
          clienteId: 'cli-juan',
          estado: OrderState.confirmado,
        ),
        seedOrder(
          id: 'A-1008-003',
          fechaIso: '2026-10-08',
          clienteId: 'cli-juan',
          estado: OrderState.recogido,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Historial (3)'), findsOneWidget);

    // Abrir el dropdown de estado.
    await tester.tap(find.byType(DropdownButton<OrderState?>));
    await tester.pumpAndSettle();

    // Los tres estados + "todos" disponibles en el menú abierto (la última
    // copia del DropdownMenuItem es la del overlay del menú; el botón
    // mantiene la suya propia en el árbol).
    expect(
      find
          .widgetWithText(DropdownMenuItem<OrderState?>, 'Todos los estados')
          .last,
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownMenuItem<OrderState?>, 'Pedido').last,
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownMenuItem<OrderState?>, 'Confirmado').last,
      findsOneWidget,
    );
    expect(
      find.widgetWithText(DropdownMenuItem<OrderState?>, 'Recogido').last,
      findsOneWidget,
    );

    // Seleccionar "Confirmado" → solo ese pedido en la lista.
    await tester.tap(
      find.widgetWithText(DropdownMenuItem<OrderState?>, 'Confirmado').last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Historial (1)'), findsOneWidget);
    expect(find.text('A-1008-002'), findsOneWidget);
    expect(find.text('A-1008-001'), findsNothing);
    expect(find.text('A-1008-003'), findsNothing);
  });
}
