import '../entities/restaurant_order.dart';
import '../entities/order_state.dart';

/// Abstract repository for restaurant orders.
abstract class OrderRepository {
  /// Create a new order.
  Future<void> createOrder(RestaurantOrder order);

  /// Get an order by ID.
  Future<RestaurantOrder?> getOrderById(String id);

  /// Get all orders for today (`fechaPedido` == current business day).
  Future<List<RestaurantOrder>> getTodayOrders();

  /// Get all orders assigned to business day [fechaIso] (`yyyy-MM-dd`).
  Future<List<RestaurantOrder>> getOrdersByDay(String fechaIso);

  /// Get all orders created since [from] (inclusive), newest first.
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from);

  /// Get orders by state.
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state);

  /// Advance the order state, validating the three-state machine.
  ///
  /// Throws [StateError] when the transition is invalid; the stored
  /// `estado` stays unchanged in that case.
  Future<void> updateOrderState(String orderId, OrderState newState);

  /// Update order with full data.
  Future<void> updateOrder(RestaurantOrder order);

  /// Get all orders (for history).
  Future<List<RestaurantOrder>> getAllOrders();

  /// Search orders by client name or phone.
  Future<List<RestaurantOrder>> searchOrders(String query);
}
