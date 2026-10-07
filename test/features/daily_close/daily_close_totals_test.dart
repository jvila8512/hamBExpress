import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/daily_close/domain/daily_close_totals.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

RestaurantOrder _order({
  required OrderState estado,
  String fecha = '2026-10-02',
  double monto = 100.0,
  List<OrderItem> items = const [],
  String? id,
}) {
  return RestaurantOrder(
    id: id ?? '${estado.name}-${monto.toStringAsFixed(0)}',
    clienteId: 'cli-1',
    estado: estado,
    montoTotal: monto,
    creadoPorUsuarioId: 'u-1',
    fechaPedido: fecha,
    items: items,
  );
}

OrderItem _item(String code, int qty, double price) =>
    OrderItem(code: code, qty: qty, price: price);

void main() {
  group('validSaleStates', () {
    test('incluye confirmado y recogido', () {
      expect(
        validSaleStates,
        containsAll([
          OrderState.confirmado,
          OrderState.recogido,
        ]),
      );
    });

    test('excluye pedido (creado sin confirmar)', () {
      expect(validSaleStates, isNot(contains(OrderState.pedido)));
    });

    test('es exactamente {confirmado, recogido}', () {
      expect(validSaleStates, {OrderState.confirmado, OrderState.recogido});
    });
  });

  group('saleOrdersOfDay — filtro por fecha y estado', () {
    test('incluye solo confirmado y recogido de la fecha pedida', () {
      final orders = [
        _order(estado: OrderState.confirmado, fecha: '2026-10-02'),
        _order(estado: OrderState.recogido, fecha: '2026-10-02'),
        _order(estado: OrderState.pedido, fecha: '2026-10-02'),
        _order(estado: OrderState.recogido, fecha: '2026-10-01'),
      ];

      final result = saleOrdersOfDay(orders, '2026-10-02');

      expect(result, hasLength(2));
    });

    test('un día sin pedidos devuelve lista vacía', () {
      final orders = [
        _order(estado: OrderState.recogido, fecha: '2026-10-03'),
      ];

      expect(saleOrdersOfDay(orders, '2026-10-02'), isEmpty);
    });
  });

  group('daySalesTotal — subtotales de línea', () {
    test('suma cantidad × precio de los pedidos incluidos', () {
      final orders = [
        _order(
          estado: OrderState.confirmado,
          fecha: '2026-10-02',
          items: [_item('pan', 2, 100), _item('carne', 1, 50)],
        ),
        _order(
          estado: OrderState.recogido,
          fecha: '2026-10-02',
          items: [_item('refresco', 3, 100)],
        ),
      ];

      final total = daySalesTotal(orders, '2026-10-02');

      expect(total, 250.0 + 300.0);
    });

    test('un pedido en estado pedido no aporta ventas', () {
      final orders = [
        _order(
          estado: OrderState.pedido,
          fecha: '2026-10-02',
          items: [_item('combo', 1, 999)],
        ),
      ];

      expect(daySalesTotal(orders, '2026-10-02'), 0.0);
    });

    test('un día sin ventas devuelve 0 sin dividir por cero', () {
      final orders = [
        _order(estado: OrderState.recogido, fecha: '2026-10-01',
            items: [_item('combo', 1, 500)]),
      ];

      expect(daySalesTotal(orders, '2026-10-02'), 0.0);
    });
  });
}
