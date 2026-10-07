import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/features/daily_close/domain/day_metrics.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

// ---------------------------------------------------------------------------
// Day Close Metrics — spec: day-management / Requirement "Day Close Metrics"
// Tarea 6.1 (RED): define el contrato de la función pura day-parameterized
// `computeDayMetrics(orders, dateIso, costByProduct)`.
//   - Ventas: subtotales de línea de confirmado/recogido de la fecha D.
//   - Ganancias: ventas − costo de producción (qty × costPrice).
//   - Top clientes: clientes de los pedidos incluidos, orden descendente.
//   - Día sin ventas → ceros y top clientes vacío.
// ---------------------------------------------------------------------------

RestaurantOrder _order({
  required String id,
  required String clienteId,
  required OrderState estado,
  required String fecha,
  List<OrderItem> items = const [],
  double montoTotal = 0,
}) {
  return RestaurantOrder(
    id: id,
    clienteId: clienteId,
    estado: estado,
    fechaPedido: fecha,
    montoTotal: montoTotal,
    creadoPorUsuarioId: 'u-1',
    items: items,
  );
}

OrderItem _item(String code, int qty, double price) =>
    OrderItem(code: code, qty: qty, price: price);

void main() {
  group('computeDayMetrics — ventas del día', () {
    test('incluye solo confirmado y recogido de la fecha pedida', () {
      // 2 recogido + 1 confirmado el 2026-10-01 (250 + 100), un pedido el
      // mismo día y un recogido de otro día quedan fuera.
      final orders = [
        _order(
          id: 'A1-1001-001',
          clienteId: 'cli-1',
          estado: OrderState.recogido,
          fecha: '2026-10-01',
          items: [_item('pan', 2, 100), _item('carne', 1, 50)],
        ),
        _order(
          id: 'A1-1001-002',
          clienteId: 'cli-2',
          estado: OrderState.confirmado,
          fecha: '2026-10-01',
          items: [_item('pan', 1, 100)],
        ),
        _order(
          id: 'A1-1001-003',
          clienteId: 'cli-3',
          estado: OrderState.pedido,
          fecha: '2026-10-01',
          items: [_item('combo', 1, 999)],
        ),
        _order(
          id: 'A1-1002-001',
          clienteId: 'cli-1',
          estado: OrderState.recogido,
          fecha: '2026-10-02',
          items: [_item('combo', 1, 500)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-01', const {});

      expect(metrics.ventas, 350.0);
    });

    test('suma subtotales de línea, no el monto del encabezado', () {
      // Encabezado desalineado: las ventas salen de cantidad × precio.
      final orders = [
        _order(
          id: 'A1-1002-010',
          clienteId: 'cli-1',
          estado: OrderState.confirmado,
          fecha: '2026-10-02',
          montoTotal: 9999,
          items: [_item('refresco', 3, 100)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-02', const {});

      expect(metrics.ventas, 300.0);
    });
  });

  group('computeDayMetrics — ganancias', () {
    test('descuenta el costo de producción de los pedidos incluidos', () {
      // 10 unidades de un producto con costo 2500 → costo 25000.
      final orders = [
        _order(
          id: 'A1-1003-001',
          clienteId: 'cli-1',
          estado: OrderState.recogido,
          fecha: '2026-10-03',
          items: [_item('hamburguesa', 10, 5000)],
        ),
        // Un pedido sin confirmar no aporta ventas NI costo.
        _order(
          id: 'A1-1003-002',
          clienteId: 'cli-2',
          estado: OrderState.pedido,
          fecha: '2026-10-03',
          items: [_item('insumo', 100, 100)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-03', {
        'hamburguesa': 2500,
        'insumo': 50,
      });

      expect(metrics.ventas, 50000.0);
      expect(metrics.costoProduccion, 25000.0);
      expect(metrics.ganancias, 25000.0);
    });

    test('un producto sin costo registrado aporta costo 0', () {
      final orders = [
        _order(
          id: 'A1-1004-001',
          clienteId: 'cli-1',
          estado: OrderState.confirmado,
          fecha: '2026-10-04',
          items: [_item('pan', 2, 100)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-04', const {});

      expect(metrics.costoProduccion, 0.0);
      expect(metrics.ganancias, metrics.ventas);
    });
  });

  group('computeDayMetrics — distribución 30/30/40', () {
    test('aplica 30/30/40 sobre las ganancias', () {
      // Ventas 60000 − costo 50000 = 10000 → 3000 / 3000 / 4000.
      final orders = [
        _order(
          id: 'A1-1002-020',
          clienteId: 'cli-1',
          estado: OrderState.recogido,
          fecha: '2026-10-02',
          items: [_item('combo', 10, 6000)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-02', {
        'combo': 5000,
      });

      expect(metrics.ventas, 60000.0);
      expect(metrics.costoProduccion, 50000.0);
      expect(metrics.ganancias, 10000.0);
      expect(metrics.yurdenis, closeTo(3000.0, 0.001));
      expect(metrics.mildrey, closeTo(3000.0, 0.001));
      expect(metrics.reinversion, closeTo(4000.0, 0.001));
    });
  });

  group('computeDayMetrics — top clientes', () {
    test('ordena por ventas descendente agregando por cliente', () {
      final orders = [
        _order(
          id: 'A1-1002-031',
          clienteId: 'cli-juan',
          estado: OrderState.recogido,
          fecha: '2026-10-02',
          items: [_item('combo', 1, 7000)],
        ),
        _order(
          id: 'A1-1002-032',
          clienteId: 'cli-juan',
          estado: OrderState.confirmado,
          fecha: '2026-10-02',
          items: [_item('refresco', 1, 5000)],
        ),
        _order(
          id: 'A1-1002-033',
          clienteId: 'cli-maria',
          estado: OrderState.recogido,
          fecha: '2026-10-02',
          items: [_item('combo', 1, 9000)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-02', const {});

      expect(metrics.topClientes, hasLength(2));
      expect(metrics.topClientes[0].clienteId, 'cli-juan');
      expect(metrics.topClientes[0].ventas, 12000.0);
      expect(metrics.topClientes[1].clienteId, 'cli-maria');
      expect(metrics.topClientes[1].ventas, 9000.0);
    });

    test('excluye pedidos en estado pedido y de otros días del ranking', () {
      final orders = [
        _order(
          id: 'A1-1002-041',
          clienteId: 'cli-maria',
          estado: OrderState.recogido,
          fecha: '2026-10-02',
          items: [_item('combo', 1, 9000)],
        ),
        // Pedido sin confirmar: no suma al ranking aunque sea grande.
        _order(
          id: 'A1-1002-042',
          clienteId: 'cli-zeta',
          estado: OrderState.pedido,
          fecha: '2026-10-02',
          items: [_item('combo', 1, 99999)],
        ),
        // Día distinto: tampoco entra.
        _order(
          id: 'A1-1003-043',
          clienteId: 'cli-otro',
          estado: OrderState.recogido,
          fecha: '2026-10-03',
          items: [_item('combo', 1, 50000)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-10-02', const {});

      expect(
        metrics.topClientes.map((c) => c.clienteId).toList(),
        ['cli-maria'],
      );
      expect(metrics.topClientes.single.ventas, 9000.0);
    });
  });

  group('computeDayMetrics — día sin ventas', () {
    test('solo pedidos sin confirmar → ceros y top clientes vacío', () {
      final orders = [
        _order(
          id: 'A1-0901-001',
          clienteId: 'cli-1',
          estado: OrderState.pedido,
          fecha: '2026-09-01',
          items: [_item('combo', 2, 500)],
        ),
        _order(
          id: 'A1-0901-002',
          clienteId: 'cli-2',
          estado: OrderState.pedido,
          fecha: '2026-09-01',
          items: [_item('refresco', 1, 200)],
        ),
      ];

      final metrics = computeDayMetrics(orders, '2026-09-01', {
        'combo': 100,
        'refresco': 50,
      });

      expect(metrics.ventas, 0.0);
      expect(metrics.costoProduccion, 0.0);
      expect(metrics.ganancias, 0.0);
      expect(metrics.topClientes, isEmpty);
    });

    test('lista vacía → ceros sin dividir por cero', () {
      final metrics = computeDayMetrics(const [], '2026-10-02', const {});

      expect(metrics.ventas, 0.0);
      expect(metrics.costoProduccion, 0.0);
      expect(metrics.ganancias, 0.0);
      expect(metrics.yurdenis, 0.0);
      expect(metrics.mildrey, 0.0);
      expect(metrics.reinversion, 0.0);
      expect(metrics.topClientes, isEmpty);
    });
  });
}
