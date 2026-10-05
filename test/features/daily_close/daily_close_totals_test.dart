import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/daily_close/domain/daily_close_totals.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

RestaurantOrder _order({
  required OrderState estado,
  double monto = 100.0,
}) {
  return RestaurantOrder(
    id: '${estado.name}-${monto.toStringAsFixed(0)}',
    clienteId: 'cli-1',
    estado: estado,
    montoTotal: monto,
    creadoPorUsuarioId: 'u-1',
  );
}

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

  group('summarizeSales — filtro por estado', () {
    test('suma solo pedidos en estado válido', () {
      final orders = [
        _order(estado: OrderState.confirmado, monto: 100),
        _order(estado: OrderState.recogido, monto: 200),
        _order(estado: OrderState.recogido, monto: 300),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 600.0);
    });

    test('excluye pedido del total', () {
      final orders = [
        _order(estado: OrderState.recogido, monto: 100),
        _order(estado: OrderState.pedido, monto: 500),
        _order(estado: OrderState.pedido, monto: 500),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 100.0);
    });
  });

  group('summarizeSales — desglose de pago (sin metodoPago)', () {
    test('cashSales y transferSales quedan en 0; toda la venta va '
        'a diferencia', () {
      final orders = [
        _order(estado: OrderState.confirmado, monto: 100),
        _order(estado: OrderState.recogido, monto: 200),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 300.0);
      expect(result.cashSales, 0.0);
      expect(result.transferSales, 0.0);
      expect(result.diferencia, 300.0);
      // Todo sale válido queda sin conciliar: 100%.
      expect(result.unconfirmedCount, 2);
      expect(result.unconfirmedPct, closeTo(100.0, 0.001));
    });
  });

  group('summarizeSales — lista vacía', () {
    test('devuelve ceros sin dividir por cero', () {
      final result = summarizeSales(const []);

      expect(result.totalSales, 0.0);
      expect(result.cashSales, 0.0);
      expect(result.transferSales, 0.0);
      expect(result.diferencia, 0.0);
      expect(result.unconfirmedCount, 0);
      expect(result.unconfirmedPct, 0.0);
    });
  });
}
