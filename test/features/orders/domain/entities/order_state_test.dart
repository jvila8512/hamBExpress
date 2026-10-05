import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

void main() {
  group('OrderState three-state machine', () {
    // ============================================================
    // pedido → confirmado → recogido (recogido es terminal)
    // ============================================================

    test('pedido can transition to confirmado', () {
      expect(OrderState.pedido.canTransitionTo(OrderState.confirmado), isTrue);
    });

    test('confirmado can transition to recogido', () {
      expect(OrderState.confirmado.canTransitionTo(OrderState.recogido), isTrue);
    });

    test('pedido cannot skip straight to recogido', () {
      expect(OrderState.pedido.canTransitionTo(OrderState.recogido), isFalse);
    });

    test('no backwards transitions exist', () {
      expect(OrderState.confirmado.canTransitionTo(OrderState.pedido), isFalse);
      expect(OrderState.recogido.canTransitionTo(OrderState.confirmado), isFalse);
      expect(OrderState.recogido.canTransitionTo(OrderState.pedido), isFalse);
    });

    test('recogido is terminal (no outgoing transitions)', () {
      for (final next in OrderState.values) {
        expect(
          OrderState.recogido.canTransitionTo(next),
          isFalse,
          reason: 'recogido must not transition to $next',
        );
      }
    });

    test('no state can transition to itself', () {
      for (final state in OrderState.values) {
        expect(
          state.canTransitionTo(state),
          isFalse,
          reason: '$state should not transition to itself',
        );
      }
    });
  });

  group('OrderState enum values', () {
    test('exactly three states in flow order', () {
      expect(OrderState.values, [
        OrderState.pedido,
        OrderState.confirmado,
        OrderState.recogido,
      ]);
    });

    test('no cancelled or legacy state survives', () {
      final names = OrderState.values.map((s) => s.name).toSet();
      expect(names, {'pedido', 'confirmado', 'recogido'});
      expect(names.contains('cancelado'), isFalse);
      expect(names.contains('registrado'), isFalse);
      expect(names.contains('enCocina'), isFalse);
    });
  });

  group('Unknown or legacy stored estado maps to pedido', () {
    RestaurantOrder orderWith(String? estado) => RestaurantOrder.fromJson({
          'id': 'A1-1003-001',
          'cliente_id': 'CLI-1',
          if (estado != null) 'estado': estado,
          'creado_por_usuario_id': 'u1',
        });

    test('legacy EN_COCINA row reads as pedido', () {
      expect(orderWith('EN_COCINA').estado, OrderState.pedido);
    });

    test('legacy cancelado row reads as pedido', () {
      expect(orderWith('cancelado').estado, OrderState.pedido);
    });

    test('missing estado reads as pedido', () {
      expect(orderWith(null).estado, OrderState.pedido);
    });

    test('known estado is preserved', () {
      expect(orderWith('confirmado').estado, OrderState.confirmado);
      expect(orderWith('recogido').estado, OrderState.recogido);
    });
  });
}
