import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';

void main() {
  group('RestaurantOrder entity', () {
    test('can be created with required fields only', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        clienteId: 'CLI-001',
        estado: OrderState.pedido,
        creadoPorUsuarioId: 'user-001',
      );

      expect(order.id, 'R1-0712-001');
      expect(order.estado, OrderState.pedido);
      expect(order.items, isEmpty);
      // fechaPedido defaults to today (yyyy-MM-dd).
      expect(order.fechaPedido, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('can be created with full fields', () {
      final order = RestaurantOrder(
        id: 'R1-0712-002',
        clienteId: 'CLI-002',
        estado: OrderState.confirmado,
        fechaPedido: '2026-10-05',
        montoTotal: 950.0,
        creadoPorUsuarioId: 'user-001',
        items: [
          OrderItem(code: 'H1', qty: 2, price: 250.0),
          OrderItem(code: 'P1', qty: 1, price: 450.0),
        ],
      );

      expect(order.fechaPedido, '2026-10-05');
      expect(order.montoTotal, 950.0);
      expect(order.items.length, 2);
    });

    test('can transition state via copyWith', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        clienteId: 'CLI-001',
        estado: OrderState.pedido,
        creadoPorUsuarioId: 'user-001',
      );

      final updated = order.copyWith(estado: OrderState.confirmado);
      expect(updated.estado, OrderState.confirmado);
      expect(updated.id, order.id); // unchanged
    });

    test('copyWith preserves other fields', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        clienteId: 'CLI-001',
        estado: OrderState.pedido,
        fechaPedido: '2026-10-05',
        montoTotal: 500.0,
        creadoPorUsuarioId: 'user-001',
      );

      final updated = order.copyWith(montoTotal: 750.0);
      expect(updated.montoTotal, 750.0);
      expect(updated.estado, OrderState.pedido); // unchanged
      expect(updated.fechaPedido, '2026-10-05'); // unchanged
    });

    test('toJson produces correct map', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        clienteId: 'CLI-001',
        estado: OrderState.pedido,
        creadoPorUsuarioId: 'user-001',
        items: [
          OrderItem(code: 'H1', qty: 2, price: 250.0),
        ],
      );

      final json = order.toJson();
      expect(json['id'], 'R1-0712-001');
      expect(json['estado'], 'pedido');
      expect(json['fecha_pedido'], order.fechaPedido);
      expect(json['items'], isA<List>());
      expect((json['items'] as List).length, 1);
    });

    test('fromJson creates correct entity', () {
      final json = {
        'id': 'R1-0712-001',
        'cliente_id': 'CLI-001',
        'estado': 'confirmado',
        'fecha_pedido': '2026-10-04',
        'creado_por_usuario_id': 'user-001',
        'items': [
          {'code': 'H1', 'qty': 2, 'price': 250.0},
        ],
      };

      final order = RestaurantOrder.fromJson(json);
      expect(order.id, 'R1-0712-001');
      expect(order.estado, OrderState.confirmado);
      expect(order.fechaPedido, '2026-10-04');
      expect(order.items.length, 1);
      expect(order.items[0].code, 'H1');
    });
  });

  group('OrderItem entity', () {
    test('can be created', () {
      final item = OrderItem(code: 'H1', qty: 2, price: 250.0);
      expect(item.code, 'H1');
      expect(item.qty, 2);
      expect(item.price, 250.0);
    });

    test('toJson produces correct map', () {
      final item = OrderItem(code: 'H1', qty: 2, price: 250.0);
      final json = item.toJson();
      expect(json['code'], 'H1');
      expect(json['qty'], 2);
      expect(json['price'], 250.0);
    });

    test('fromJson creates correct entity', () {
      final json = {'code': 'H1', 'qty': 2, 'price': 250.0};
      final item = OrderItem.fromJson(json);
      expect(item.code, 'H1');
      expect(item.qty, 2);
      expect(item.price, 250.0);
    });
  });
}
