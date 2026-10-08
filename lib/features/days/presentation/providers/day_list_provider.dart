import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:etecsa/features/daily_close/presentation/providers/daily_close_datasource_provider.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Day List — spec: day-management / "Day List with Counts and Status"
// ---------------------------------------------------------------------------

/// Fila de la lista de días (`/days`).
class DayEntry {
  /// Día de negocio (`yyyy-MM-dd`).
  final String fecha;

  /// Pedidos con `fechaPedido == fecha` (0 si el día solo tiene cierre).
  final int orderCount;

  /// El día tiene fila en `DailySummaries` (cerrado).
  final bool cerrado;

  const DayEntry({
    required this.fecha,
    required this.orderCount,
    required this.cerrado,
  });
}

/// Agrupa [orders] por `fechaPedido` y marca cada día como cerrado según
/// [fechasCerradas] (fechas con cierre persistido).
///
/// - Un día solo aparece si tiene pedidos O cierre persistido: no se
///   fabrica el calendario.
/// - Orden descendente (más reciente primero).
List<DayEntry> buildDayEntries(
  List<RestaurantOrder> orders,
  Set<String> fechasCerradas,
) {
  final conteo = <String, int>{};
  for (final order in orders) {
    conteo[order.fechaPedido] = (conteo[order.fechaPedido] ?? 0) + 1;
  }

  final fechas = <String>{...conteo.keys, ...fechasCerradas};
  final entries = <DayEntry>[
    for (final fecha in fechas)
      DayEntry(
        fecha: fecha,
        orderCount: conteo[fecha] ?? 0,
        cerrado: fechasCerradas.contains(fecha),
      ),
  ]..sort((a, b) => b.fecha.compareTo(a.fecha));
  return entries;
}

/// Días con actividad, del más reciente al más antiguo.
///
/// `autoDispose`: al volver a `/days` (p. ej. tras mover un pedido) los
/// conteos se recalculan contra el repositorio en lugar de servirse
/// cacheados.
final dayListProvider = FutureProvider.autoDispose<List<DayEntry>>((
  ref,
) async {
  final orders = await ref.watch(orderRepositoryProvider).getAllOrders();
  final summaries =
      await ref.watch(dailyCloseDatasourceProvider).getAllSummaries();
  return buildDayEntries(orders, summaries.map((s) => s.fecha).toSet());
});
