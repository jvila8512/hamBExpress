import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart';
import 'package:etecsa/features/contacts/domain/repositories/contact_repository.dart';
import 'package:etecsa/features/contacts/presentation/providers/contact_provider.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

// ---------------------------------------------------------------------------
// Fakes (hand-rolled, sin mocks externos)
// ---------------------------------------------------------------------------

class _FakeOrderRepository implements OrderRepository {
  List<RestaurantOrder> todayOrders = [];
  final List<RestaurantOrder> created = [];

  @override
  Future<void> createOrder(RestaurantOrder order) async {
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
  Future<List<RestaurantOrder>> getTodayOrders() async =>
      List.of(todayOrders);

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) async => const [];

  @override
  Future<void> updateOrder(RestaurantOrder order) async {}

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) async {}
}

class _FakeSmsService extends SmsService {
  bool result = true;

  @override
  Future<bool> sendSms(String phoneNumber, String message) async => result;
}

class _FakeContactRepository implements ContactRepository {
  List<String> kitchenPhones = ['555-1234'];

  @override
  Future<void> createContact(TrustedContact contact) async {}

  @override
  Future<void> deleteContact(String id) async {}

  @override
  Future<List<String>> getActivePhonesForRole(String rol) async =>
      List.of(kitchenPhones);

  @override
  Future<TrustedContact?> getContactById(String id) async => null;

  @override
  Future<List<TrustedContact>> getContacts({String? rol}) async => const [];

  @override
  Future<void> toggleContactActive(String id, bool active) async {}

  @override
  Future<void> updateContact(TrustedContact contact) async {}
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

ProviderContainer _makeContainer(
  _FakeOrderRepository repo,
  _FakeSmsService sms,
  _FakeContactRepository contacts,
) {
  final container = ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWithValue(repo),
      smsServiceProvider.overrideWithValue(sms),
      contactRepositoryProvider.overrideWithValue(contacts),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('isSmsPendingState (función pura)', () {
    test('pedido y confirmado son pendientes', () {
      expect(isSmsPendingState(OrderState.pedido), isTrue);
      expect(isSmsPendingState(OrderState.confirmado), isTrue);
    });

    test('recogido (terminal) NO es pendiente', () {
      expect(isSmsPendingState(OrderState.recogido), isFalse);
    });
  });

  group('OrderNotifier.loadTodayOrders rehidrata pendientes', () {
    test('pedido de hoy no-terminal → pendiente', () async {
      final repo = _FakeOrderRepository()
        ..todayOrders = [_sampleOrder()];
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadTodayOrders();

      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
    });

    test('recogido (terminal) → NO pendiente tras recargar', () async {
      final repo = _FakeOrderRepository()
        ..todayOrders = [
          _sampleOrder().copyWith(estado: OrderState.recogido),
        ];
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadTodayOrders();

      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
    });
  });
}
