import 'package:drift/native.dart';

// `app_database.dart` también declara las data classes de drift con los
// mismos nombres (RestaurantOrder/OrderItem/RestaurantClient): solo se
// necesita `AppDatabase`, el resto causaría import ambiguos.
import 'package:etecsa/core/database/app_database.dart' show AppDatabase;
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/domain/repositories/client_repository.dart';
import 'package:etecsa/features/daily_close/domain/day_metrics.dart';
import 'package:etecsa/features/daily_close/infrastructure/daily_close_datasource.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';

// ---------------------------------------------------------------------------
// Fakes compartidos de los tests de días (6.3) — hand-rolled, sin mocks
// externos (mismo criterio que order_notifier_create_order_test.dart).
// ---------------------------------------------------------------------------

/// Pedido con `fechaPedido` explícita (`yyyy-MM-dd`).
RestaurantOrder seedOrder({
  required String id,
  required String fechaIso,
  String clienteId = 'cli-juan',
  OrderState estado = OrderState.recogido,
  double monto = 100,
  DateTime? fechaCreacion,
  List<OrderItem> items = const [OrderItem(code: 'H1', qty: 1, price: 100)],
}) {
  return RestaurantOrder(
    id: id,
    clienteId: clienteId,
    estado: estado,
    montoTotal: monto,
    creadoPorUsuarioId: 'u1',
    fechaPedido: fechaIso,
    fechaCreacion: fechaCreacion ?? DateTime(2026, 10, 2, 10, 30),
    items: items,
  );
}

/// Cliente con nombre visible en las filas de pedido.
RestaurantClient seedClient({required String id, required String nombre}) {
  return RestaurantClient(id: id, nombre: nombre, telefono: '');
}

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository([List<RestaurantOrder>? seed])
      : orders = List.of(seed ?? const []);

  final List<RestaurantOrder> orders;

  /// Registro de `updateOrder` — el test de mover día afirma el cambio.
  final List<RestaurantOrder> updated = [];

  @override
  Future<void> createOrder(RestaurantOrder order) async {
    orders.add(order);
  }

  @override
  Future<List<RestaurantOrder>> getAllOrders() async => List.of(orders);

  @override
  Future<RestaurantOrder?> getOrderById(String id) async =>
      orders.where((o) => o.id == id).firstOrNull;

  @override
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state) async =>
      orders.where((o) => o.estado == state).toList();

  @override
  Future<List<RestaurantOrder>> getOrdersByDay(String fechaIso) async =>
      orders.where((o) => o.fechaPedido == fechaIso).toList();

  @override
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from) async =>
      List.of(orders);

  @override
  Future<List<RestaurantOrder>> getTodayOrders() async => List.of(orders);

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) async => const [];

  @override
  Future<void> updateOrder(RestaurantOrder order) async {
    updated.add(order);
    final index = orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) orders[index] = order;
  }

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      orders[index] = orders[index].copyWith(estado: newState);
    }
  }
}

class FakeClientRepository implements ClientRepository {
  FakeClientRepository([List<RestaurantClient>? seed])
      : clients = List.of(seed ?? const []);

  final List<RestaurantClient> clients;

  @override
  Future<void> createClient(RestaurantClient client) async {
    clients.add(client);
  }

  @override
  Future<RestaurantClient?> getClientById(String id) async =>
      clients.where((c) => c.id == id).firstOrNull;

  @override
  Future<List<RestaurantClient>> searchClients(String query) async => clients
      .where(
        (c) =>
            c.nombre.contains(query) || c.telefono.contains(query),
      )
      .toList();

  @override
  Future<List<RestaurantClient>> getAllClients() async => List.of(clients);

  @override
  Future<void> updateClient(RestaurantClient client) async {
    final index = clients.indexWhere((c) => c.id == client.id);
    if (index >= 0) clients[index] = client;
  }

  @override
  Future<void> deleteClient(String id) async {
    clients.removeWhere((c) => c.id == id);
  }
}

/// `DailyCloseDatasource` sobre una BD en memoria — nunca toca
/// `AppDatabase.instance`.
class InMemoryCloseDatasource extends DailyCloseDatasource {
  InMemoryCloseDatasource(this.db) : super(db);

  final AppDatabase db;

  /// Cierre de [fecha] como admin (camino feliz) para sembrar días cerrados.
  Future<void> closeAsAdmin({
    required String fecha,
    required DayMetrics metrics,
    String topClientesJson = '[]',
  }) {
    return closeDay(
      dateIso: fecha,
      actorRole: 'admin',
      metrics: metrics,
      topClientesJson: topClientesJson,
    );
  }
}

/// Crea la BD en memoria para un test de widgets; ciérrala en `tearDown`.
AppDatabase createTestDb() => AppDatabase.forTesting(NativeDatabase.memory());
