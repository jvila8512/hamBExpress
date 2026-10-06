import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Fakes (sin mocks externos: hand-rolled, 2 fakes vs 3+ asserts por test)
// ---------------------------------------------------------------------------

class _FakeOrderRepository implements OrderRepository {
  final List<RestaurantOrder> created = [];
  bool throwOnCreate = false;

  @override
  Future<void> createOrder(RestaurantOrder order) async {
    if (throwOnCreate) throw Exception('DB caída');
    created.add(order);
  }

  @override
  Future<List<RestaurantOrder>> getAllOrders() async => List.of(created);

  @override
  Future<RestaurantOrder?> getOrderById(String id) async =>
      created.where((o) => o.id == id).firstOrNull;

  @override
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state) async =>
      created.where((o) => o.estado == state).toList();

  @override
  Future<List<RestaurantOrder>> getOrdersByDay(String fechaIso) async =>
      created.where((o) => o.fechaPedido == fechaIso).toList();

  @override
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from) async =>
      List.of(created);

  @override
  Future<List<RestaurantOrder>> getTodayOrders() async => List.of(created);

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) async => const [];

  @override
  Future<void> updateOrder(RestaurantOrder order) async {}

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RestaurantOrder _sampleOrder() => RestaurantOrder(
      id: 'R1-0101-001',
      clienteId: 'CLI-1',
      estado: OrderState.pedido,
      creadoPorUsuarioId: 'u1',
      items: [OrderItem(code: 'H1', qty: 2, price: 100)],
    );

ProviderContainer _makeContainer(_FakeOrderRepository repo) {
  final container = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('OrderNotifier.createOrder no SMS: guarda y no traga errores', () {
    test('repo-ok → guarda el pedido, lo apila y no setea error', () async {
      final repo = _FakeOrderRepository();
      final container = _makeContainer(repo);
      final notifier = container.read(orderProvider.notifier);

      await notifier.createOrder(_sampleOrder());

      expect(repo.created, hasLength(1));
      expect(notifier.orders.map((o) => o.id), contains('R1-0101-001'));
      expect(notifier.error, isNull);
      expect(notifier.isLoading, isFalse);
    });

    test('varios pedidos → el más nuevo queda primero en la lista', () async {
      final repo = _FakeOrderRepository();
      final container = _makeContainer(repo);
      final notifier = container.read(orderProvider.notifier);

      await notifier.createOrder(_sampleOrder());
      await notifier
          .createOrder(_sampleOrder().copyWith(id: 'R1-0101-002'));

      expect(notifier.orders.map((o) => o.id).toList(),
          ['R1-0101-002', 'R1-0101-001']);
      expect(notifier.error, isNull);
    });

    test('repo-throw → relanza para que el form lo vea y setea error',
        () async {
      final repo = _FakeOrderRepository()..throwOnCreate = true;
      final container = _makeContainer(repo);
      final notifier = container.read(orderProvider.notifier);

      await expectLater(
        () => notifier.createOrder(_sampleOrder()),
        throwsException,
      );
      expect(notifier.error, isNotNull);
      expect(notifier.orders, isEmpty);
      expect(notifier.isLoading, isFalse);
    });
  });
}
