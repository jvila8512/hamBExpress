import 'dart:convert';

import 'package:etecsa/features/daily_close/domain/daily_close_totals.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

/// Cliente del día con su total de ventas, para la sección
/// "Top de Clientes" del cierre.
class TopClienteEntry {
  final String clienteId;
  final double ventas;

  const TopClienteEntry({required this.clienteId, required this.ventas});
}

/// Métricas puras del cierre de día para una fecha D.
///
/// `ventas`, `costoProduccion` y `topClientes` son la fuente de verdad;
/// `ganancias` y la distribución 30/30/40 se derivan para que el
/// invariante `ganancias = ventas − costo` no pueda desincronizarse.
class DayMetrics {
  final double ventas;
  final double costoProduccion;
  final List<TopClienteEntry> topClientes;

  const DayMetrics({
    required this.ventas,
    required this.costoProduccion,
    this.topClientes = const [],
  });

  double get ganancias => ventas - costoProduccion;
  double get yurdenis => ganancias * 0.30;
  double get mildrey => ganancias * 0.30;
  double get reinversion => ganancias * 0.40;
}

/// Calcula las métricas del día [dateIso] (`yyyy-MM-dd`).
///
/// - **Ventas**: subtotales de línea (cantidad × precio) de los pedidos
///   `confirmado`/`recogido` de esa fecha.
/// - **Costo de producción**: cantidad × [costByProduct] por código de
///   producto (0 si el producto no tiene costo registrado).
/// - **Top clientes**: agrega ventas por cliente de los pedidos
///   incluidos, orden descendente (empate → `clienteId` ascendente).
///
/// Día sin ventas → ceros y `topClientes` vacío.
DayMetrics computeDayMetrics(
  List<RestaurantOrder> orders,
  String dateIso,
  Map<String, double> costByProduct,
) {
  final saleOrders = saleOrdersOfDay(orders, dateIso);

  double ventas = 0;
  double costo = 0;
  final ventasPorCliente = <String, double>{};

  for (final order in saleOrders) {
    double subtotalPedido = 0;
    for (final item in order.items) {
      final subtotalLinea = item.qty * item.price;
      ventas += subtotalLinea;
      subtotalPedido += subtotalLinea;
      costo += item.qty * (costByProduct[item.code] ?? 0.0);
    }
    ventasPorCliente[order.clienteId] =
        (ventasPorCliente[order.clienteId] ?? 0.0) + subtotalPedido;
  }

  final topClientes = ventasPorCliente.entries
      .map((entry) => TopClienteEntry(clienteId: entry.key, ventas: entry.value))
      .toList()
    ..sort((a, b) {
      final porVentas = b.ventas.compareTo(a.ventas);
      if (porVentas != 0) return porVentas;
      return a.clienteId.compareTo(b.clienteId);
    });

  return DayMetrics(
    ventas: ventas,
    costoProduccion: costo,
    topClientes: topClientes,
  );
}

/// Serializa el ranking de [entries] para `DailySummaries.topClientesJson`.
///
/// Formato: `[{"clienteId":"cli-1","ventas":100.0}]`.
String encodeTopClientes(List<TopClienteEntry> entries) {
  return jsonEncode([
    for (final entry in entries)
      {'clienteId': entry.clienteId, 'ventas': entry.ventas},
  ]);
}

/// Lee `DailySummaries.topClientesJson`. Vacío o JSON inválido → lista vacía
/// (el cierre debe seguir siendo visible aunque el ranking esté corrupto).
List<TopClienteEntry> decodeTopClientes(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final raw in decoded)
        if (raw is Map)
          TopClienteEntry(
            clienteId: raw['clienteId']?.toString() ?? '',
            ventas: (raw['ventas'] as num?)?.toDouble() ?? 0,
          ),
    ];
  } catch (_) {
    return const [];
  }
}
