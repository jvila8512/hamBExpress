import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart' as domain;
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:uuid/uuid.dart';

/// Resuelve el próximo valor de `intentos_reenvio`.
///
/// Si se pasa [override], lo setea tal cual; si no, incrementa en 1.
/// Función pura para que la regla sea testeable sin BD.
int resolveNextRetryCount({required int current, int? override}) =>
    override ?? current + 1;

/// Drift datasource for restaurant orders.
class OrderDatasource {
  final AppDatabase _db;
  final _uuid = const Uuid();

  OrderDatasource(this._db);

  Future<void> createOrder(domain.RestaurantOrder order) async {
    await _db.into(_db.restaurantOrders).insert(
      RestaurantOrdersCompanion.insert(
        id: order.id,
        // Legacy NOT NULL column; the domain no longer models order types.
        tipoPedido: '',
        clienteId: order.clienteId,
        estado: order.estado.name,
        montoTotal: Value(order.montoTotal),
        creadoPorUsuarioId: order.creadoPorUsuarioId,
        fechaPedido: Value(order.fechaPedido),
      ),
    );

    // Insert order items
    for (final item in order.items) {
      await _db.into(_db.restaurantOrderItems).insert(
        RestaurantOrderItemsCompanion.insert(
          id: _uuid.v4(),
          orderId: order.id,
          productoCodigo: item.code,
          cantidad: item.qty.toDouble(),
          precioUnitario: item.price,
          subtotal: item.subtotal,
        ),
      );
    }
  }

  Future<domain.RestaurantOrder?> getOrderById(String id) async {
    final row = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final items = await _getOrderItems(id);
    return _mapRowToOrder(row, items);
  }

  Future<List<domain.RestaurantOrder>> getTodayOrders() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.fechaCreacion.isBiggerOrEqualValue(startOfDay))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <domain.RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<List<domain.RestaurantOrder>> getOrdersSince(DateTime from) async {
    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.fechaCreacion.isBiggerOrEqualValue(from))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    return rows
        .map((row) => _mapRowToOrder(row, const <RestaurantOrderItem>[]))
        .toList();
  }

  Future<List<domain.RestaurantOrder>> getOrdersByState(OrderState state) async {
    final stateName = state.name;
    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.estado.equals(stateName))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <domain.RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<void> updateOrderState(String orderId, OrderState newState) async {
    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .write(RestaurantOrdersCompanion(
          estado: Value(newState.name),
        ));
  }

  /// Persiste el resultado del envío del SMS PED.
  ///
  /// Actualiza `sms_enviado` e `intentos_reenvio`: si se pasa [intentos]
  /// lo setea tal cual; si no, incrementa el valor actual en 1.
  Future<void> markSmsStatus(
    String orderId, {
    required bool enviado,
    int? intentos,
  }) async {
    final current = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .getSingleOrNull();
    final next = resolveNextRetryCount(
      current: current?.intentosReenvio ?? 0,
      override: intentos,
    );
    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .write(RestaurantOrdersCompanion(
          smsEnviado: Value(enviado),
          intentosReenvio: Value(next),
        ));
  }

  /// Persiste la confirmación (ACK) del SMS por parte de Cocina.
  Future<void> markSmsConfirmado(String orderId, bool confirmado) async {
    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .write(RestaurantOrdersCompanion(
          smsConfirmado: Value(confirmado),
        ));
  }

  Future<void> updateOrder(domain.RestaurantOrder order) async {
    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(order.id)))
        .write(RestaurantOrdersCompanion(
          clienteId: Value(order.clienteId),
          estado: Value(order.estado.name),
          montoTotal: Value(order.montoTotal),
          fechaPedido: Value(order.fechaPedido),
        ));
  }

  Future<List<domain.RestaurantOrder>> getAllOrders() async {
    final rows = await (_db.select(_db.restaurantOrders)
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <domain.RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<List<domain.RestaurantOrder>> searchOrders(String query) async {
    // Search by ID or client ID
    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) =>
              o.id.contains(query) | o.clienteId.contains(query))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <domain.RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<List<RestaurantOrderItem>> _getOrderItems(String orderId) async {
    return (_db.select(_db.restaurantOrderItems)
          ..where((i) => i.orderId.equals(orderId)))
        .get();
  }

  domain.RestaurantOrder _mapRowToOrder(
    RestaurantOrder row,
    List<RestaurantOrderItem> items,
  ) {
    return domain.RestaurantOrder(
      id: row.id,
      clienteId: row.clienteId,
      estado: _parseState(row.estado),
      montoTotal: row.montoTotal,
      creadoPorUsuarioId: row.creadoPorUsuarioId,
      fechaPedido: row.fechaPedido,
      fechaCreacion: row.fechaCreacion,
      items: items.map((i) => domain.OrderItem(
        code: i.productoCodigo,
        qty: i.cantidad.toInt(),
        price: i.precioUnitario,
      )).toList(),
    );
  }

  OrderState _parseState(String state) {
    return OrderState.values.firstWhere(
      (s) => s.name == state,
      orElse: () => OrderState.pedido,
    );
  }
}
