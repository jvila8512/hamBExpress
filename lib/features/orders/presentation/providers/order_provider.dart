import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/orders/infrastructure/repositories/order_repository_impl.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _orderDatasourceProvider = Provider<OrderDatasource>((ref) {
  return OrderDatasource(AppDatabase.instance);
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.watch(_orderDatasourceProvider));
});

final orderProvider = NotifierProvider<OrderNotifier, OrderState>(
  () => OrderNotifier(),
);

// ---------------------------------------------------------------------------
// Order Notifier
// ---------------------------------------------------------------------------

class OrderNotifier extends Notifier<OrderState> {
  List<RestaurantOrder> _orders = [];
  String? _error;
  bool _isLoading = false;

  OrderRepository get _repository => ref.read(orderRepositoryProvider);

  @override
  OrderState build() {
    return OrderState.pedido;
  }

  List<RestaurantOrder> get orders => _orders;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Create a new order.
  ///
  /// Repository errors are recorded in [error] and rethrown so the UI
  /// can react instead of showing a false success.
  Future<void> createOrder(RestaurantOrder order) async {
    _isLoading = true;
    _error = null;

    try {
      await _repository.createOrder(order);
    } catch (e) {
      _error = 'Error creating order: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }

    _orders = [order, ..._orders];
  }

  /// Update order state through the validated transition rule.
  ///
  /// Errors are recorded in [error]; the local list is only updated after
  /// the repository accepts the transition.
  Future<void> updateState(String orderId, OrderState newState) async {
    _error = null;

    try {
      await _repository.updateOrderState(orderId, newState);

      _orders = _orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(estado: newState);
        }
        return o;
      }).toList();
    } catch (e) {
      _error = 'Error updating order state: $e';
    }
  }

  /// Load today's orders from the repository.
  Future<void> loadTodayOrders() async {
    _isLoading = true;
    _error = null;

    try {
      _orders = await _repository.getTodayOrders();
    } catch (e) {
      _error = 'Error loading orders: $e';
    } finally {
      _isLoading = false;
    }
  }
}
