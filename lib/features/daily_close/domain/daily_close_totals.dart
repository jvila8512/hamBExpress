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

/// Agregado puro de ventas del día sobre pedidos ya filtrados por fecha.
///
/// Solo los pedidos en [validSaleStates] alimentan totales. El modelo de
/// tres estados no modela método de pago, por lo que el desglose de pago
/// (`cashSales`/`transferSales`) es 0 y toda la venta queda en
/// `diferencia` (aún sin conciliar).
class SalesBreakdown {
  final double totalSales;
  final double cashSales;
  final double transferSales;
  final double diferencia;
  final int unconfirmedCount;
  final double unconfirmedPct;

  const SalesBreakdown({
    required this.totalSales,
    required this.cashSales,
    required this.transferSales,
    required this.diferencia,
    required this.unconfirmedCount,
    required this.unconfirmedPct,
  });
}

/// Summarizes the day's sales from [orders], counting only valid sale states.
SalesBreakdown summarizeSales(List<RestaurantOrder> orders) {
  double totalSales = 0;
  int unconfirmedCount = 0;

  for (final order in orders) {
    if (!validSaleStates.contains(order.estado)) continue;

    totalSales += order.montoTotal;
    unconfirmedCount++;
  }

  const cashSales = 0.0;
  const transferSales = 0.0;
  final diferencia = totalSales - cashSales - transferSales;
  final unconfirmedPct =
      totalSales > 0 ? diferencia / totalSales * 100 : 0.0;

  return SalesBreakdown(
    totalSales: totalSales,
    cashSales: cashSales,
    transferSales: transferSales,
    diferencia: diferencia,
    unconfirmedCount: unconfirmedCount,
    unconfirmedPct: unconfirmedPct,
  );
}

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
