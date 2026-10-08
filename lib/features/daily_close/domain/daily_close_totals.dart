import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

/// Estados cuyos pedidos cuentan como venta del día en el cierre.
///
/// Máquina de tres estados: pedido → confirmado → recogido. Se excluye
/// `pedido` (creado pero sin confirmar) y solo `confirmado`/`recogido`
/// alimentan los totales.
const Set<OrderState> validSaleStates = {
  OrderState.confirmado,
  OrderState.recogido,
};

/// Returns `true` if orders in [state] count as sales for the daily close.
bool isValidSale(OrderState state) => validSaleStates.contains(state);

/// Pedidos del día [dateIso] (`yyyy-MM-dd`) que cuentan como venta:
/// solo [validSaleStates] y solo con `fechaPedido == dateIso`.
List<RestaurantOrder> saleOrdersOfDay(
  List<RestaurantOrder> orders,
  String dateIso,
) {
  return orders
      .where(
        (order) =>
            order.fechaPedido == dateIso &&
            validSaleStates.contains(order.estado),
      )
      .toList();
}

/// Ventas del día [dateIso] calculadas por subtotales de línea
/// (cantidad × precio), no por el monto del encabezado.
double daySalesTotal(List<RestaurantOrder> orders, String dateIso) {
  double total = 0;
  for (final order in saleOrdersOfDay(orders, dateIso)) {
    for (final item in order.items) {
      total += item.qty * item.price;
    }
  }
  return total;
}
