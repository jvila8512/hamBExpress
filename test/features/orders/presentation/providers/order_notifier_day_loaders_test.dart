import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Day loaders del OrderNotifier — spec: order-management / "Order Day Field".
// Tarea 7.1 (RED): `loadOrdersByDay(fechaIso)` aún no existe en el notifier.
// ---------------------------------------------------------------------------

/// Repositorio fake con días conocidos y fallo inyectable.
class _DayFakeRepository implements OrderRepository {
  _DayFakeRepository(this.byDay);

  /// `fechaIso` → pedidos de ese día.
  final Map<String, List<RestaurantOrder>> byDay;

  /// Días realmente solicitados (prueba que delega en `getOrdersByDay`).
  final List<String> requestedDays = [];

  bool throwOnLoad = false;

  @override
  Future<List<RestaurantOrder>> getOrdersByDay(String fechaIso) async {
    if (throwOnLoad) throw Exception('DB caída');
    requestedDays.add(fechaIso);
    return List.of(byDay[fechaIso] ?? const []);
  }

  @override
  Future<List<RestaurantOrder>> getTodayOrders() =>
      getOrdersByDay('2026-10-08');

  @override
  Future<void> createOrder(RestaurantOrder order) async {}

  @override
  Future<List<RestaurantOrder>> getAllOrders() async => const [];

  @override
  Future<RestaurantOrder?> getOrderById(String id) async => null;

  @override
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state) async =>
      const [];

  @override
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from) async => const [];

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) async => const [];

  @override
  Future<void> updateOrder(RestaurantOrder order) async {}

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) async {}
}

RestaurantOrder _order(String id, String fechaIso) => RestaurantOrder(
      id: id,
      clienteId: 'cli-1',
      creadoPorUsuarioId: 'u1',
      fechaPedido: fechaIso,
      estado: OrderState.pedido,
    );

ProviderContainer _makeContainer(_DayFakeRepository repo) {
  final container = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('OrderNotifier.loadOrdersByDay (day loaders)', () {
    test('carga solo los pedidos del día pedido y apaga el loading', () async {
      final repo = _DayFakeRepository({
        '2026-10-05': [_order('A1-1005-001', '2026-10-05'), _order('A1-1005-002', '2026-10-05')],
        '2026-10-06': [_order('A1-1006-001', '2026-10-06')],
      });
      final container = _makeContainer(repo);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadOrdersByDay('2026-10-05');

      expect(repo.requestedDays, ['2026-10-05']);
      expect(notifier.orders.map((o) => o.id).toList(),
          ['A1-1005-001', 'A1-1005-002']);
      expect(notifier.error, isNull);
      expect(notifier.isLoading, isFalse);
    });

    test('un día sin pedidos deja la lista vacía sin error', () async {
      final repo = _DayFakeRepository({
        '2026-10-05': [_order('A1-1005-001', '2026-10-05')],
      });
      final container = _makeContainer(repo);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadOrdersByDay('2026-10-07');

      expect(notifier.orders, isEmpty);
      expect(notifier.error, isNull);
      expect(notifier.isLoading, isFalse);
    });

    test('si el repositorio falla registra el error y no rompe el estado',
        () async {
      final repo = _DayFakeRepository({})..throwOnLoad = true;
      final container = _makeContainer(repo);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadOrdersByDay('2026-10-05');

      expect(notifier.error, isNotNull);
      expect(notifier.orders, isEmpty);
      expect(notifier.isLoading, isFalse);
    });
  });
}
