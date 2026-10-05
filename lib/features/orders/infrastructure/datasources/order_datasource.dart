import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart' as domain;
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:uuid/uuid.dart';

/// Hoy en formato de negocio `yyyy-MM-dd`.
String _todayIso() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

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

  /// Orders assigned to the current business day (`fechaPedido == hoy`).
  Future<List<domain.RestaurantOrder>> getTodayOrders() {
    return getOrdersByDay(_todayIso());
  }

  /// Orders assigned to business day [fechaIso] (`yyyy-MM-dd`), newest first.
  Future<List<domain.RestaurantOrder>> getOrdersByDay(String fechaIso) async {
    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.fechaPedido.equals(fechaIso))
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

  /// Advances the state of [orderId] to [newState].
  ///
  /// Validates the move with the three-state machine: an invalid
  /// transition throws [StateError] and leaves `estado` untouched
  /// (spec: Invalid transition leaves estado unchanged).
  Future<void> updateOrderState(String orderId, OrderState newState) async {
    final current = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .getSingleOrNull();
    if (current == null) {
      throw StateError('Order $orderId not found');
    }

    final from = _parseState(current.estado);
    if (!from.canTransitionTo(newState)) {
      throw StateError(
        'Invalid order transition ${current.estado} → ${newState.name}',
      );
    }

    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .write(RestaurantOrdersCompanion(
          estado: Value(newState.name),
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
