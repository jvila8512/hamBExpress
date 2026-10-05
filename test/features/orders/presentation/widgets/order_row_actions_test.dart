import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/widgets/order_row_actions.dart';

// ---------------------------------------------------------------------------
// Order Row Actions — spec: order-management / Requirement "Order Row Actions"
// Task 3.1 (RED): asserts the visible state-button label per state.
//   pedido     -> "Confirmar"      (tap advances to confirmado)
//   confirmado -> "Marcar recogido" (tap advances to recogido)
//   recogido   -> "Recogido"        (terminal: NO transition action)
// ---------------------------------------------------------------------------

RestaurantOrder _order(OrderState state) => RestaurantOrder(
      id: 'A1-1005-001',
      clienteId: 'cliente-1',
      estado: state,
      montoTotal: 150,
      creadoPorUsuarioId: 'u1',
      items: const [],
    );

Future<void> _pumpRowActions(
  WidgetTester tester, {
  required OrderState state,
  ValueChanged<OrderState>? onAdvance,
  VoidCallback? onInspect,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrderRowActions(
          order: _order(state),
          clientCell: '53512345',
          onAdvance: onAdvance,
          onInspect: onInspect,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('pedido muestra "Confirmar" y al tocarla avanza a confirmado',
      (tester) async {
    OrderState? advanced;
    await _pumpRowActions(
      tester,
      state: OrderState.pedido,
      onAdvance: (next) => advanced = next,
    );

    expect(find.text('Confirmar'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(advanced, OrderState.confirmado);
  });

  testWidgets(
      'confirmado muestra "Marcar recogido" y al tocarla avanza a recogido',
      (tester) async {
    OrderState? advanced;
    await _pumpRowActions(
      tester,
      state: OrderState.confirmado,
      onAdvance: (next) => advanced = next,
    );

    expect(find.text('Marcar recogido'), findsOneWidget);

    await tester.tap(find.text('Marcar recogido'));
    await tester.pump();

    expect(advanced, OrderState.recogido);
  });

  testWidgets(
      'recogido es terminal: muestra "Recogido" sin acción de transición',
      (tester) async {
    OrderState? advanced;
    var inspected = false;
    await _pumpRowActions(
      tester,
      state: OrderState.recogido,
      onAdvance: (next) => advanced = next,
      onInspect: () => inspected = true,
    );

    expect(find.text('Recogido'), findsOneWidget);

    await tester.tap(find.text('Recogido'));
    await tester.pump();

    expect(advanced, isNull, reason: 'terminal state must not transition');
    expect(inspected, isTrue);
  });

  testWidgets('la fila expone exactamente las tres acciones del spec',
      (tester) async {
    await _pumpRowActions(tester, state: OrderState.pedido);

    expect(find.byTooltip('Enviar SMS'), findsOneWidget);
    expect(find.byTooltip('Llamar'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);
  });
}
