import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/daily_close/domain/daily_close_totals.dart';
import 'package:etecsa/features/daily_close/domain/day_metrics.dart';
import 'package:etecsa/features/daily_close/presentation/providers/daily_close_datasource_provider.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Daily Close — spec: daily-close (día arbitrario, sin tabs, 30/30/40,
// Top de Clientes, cierre admin-only) + day-management (Day Close Metrics)
// ---------------------------------------------------------------------------

/// Hoy en `yyyy-MM-dd` (zona horaria local del dispositivo).
String todayIso() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

/// Línea del desglose por producto del día: cantidad y monto agregados por
/// código. Sin división por categoría (la spec la elimina).
class ProductSalesEntry {
  final String productCode;
  final int quantity;
  final double amount;

  const ProductSalesEntry({
    required this.productCode,
    required this.quantity,
    required this.amount,
  });
}

/// Fila del "Top de clientes" ya resuelta a nombre visible
/// (`clienteId` → `RestaurantClients.nombre`, con fallback al id).
class TopClienteRow {
  final String clienteId;
  final String nombre;
  final double ventas;

  const TopClienteRow({
    required this.clienteId,
    required this.nombre,
    required this.ventas,
  });
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DailyCloseState {
  final bool isLoading;

  /// Error de carga (día no disponible hasta recargar).
  final String? error;

  /// Día en pantalla (`yyyy-MM-dd`); `null` antes de la primera carga.
  final String? date;

  /// Todos los pedidos del día (incluye `pedido`: alimenta los indicadores).
  final List<RestaurantOrder> orders;

  /// Ventas/costo/ganancias y distribución 30/30/40 del día.
  final DayMetrics metrics;

  /// Desglose por producto de los pedidos `confirmado`/`recogido`.
  final List<ProductSalesEntry> topProducts;

  /// Ranking de clientes del día (ya con nombre visible).
  final List<TopClienteRow> topClientes;

  /// El día ya tiene fila en `DailySummaries`.
  final bool isClosed;

  /// Mensaje del último cierre exitoso (se limpia en la siguiente carga).
  final String? closeMessage;

  /// Rechazo del último cierre (p. ej. rol ≠ admin en la capa de datos).
  final String? closeError;

  const DailyCloseState({
    this.isLoading = false,
    this.error,
    this.date,
    this.orders = const [],
    this.metrics = const DayMetrics(ventas: 0, costoProduccion: 0),
    this.topProducts = const [],
    this.topClientes = const [],
    this.isClosed = false,
    this.closeMessage,
    this.closeError,
  });

  /// Los tres mensajes (`error`, `closeMessage`, `closeError`) SIEMPRE se
  /// reemplazan por los argumentos (null = limpiar): son avisos de un solo
  /// disparo. El resto de los campos conserva su valor si no se pasa.
  DailyCloseState copyWith({
    bool? isLoading,
    String? date,
    List<RestaurantOrder>? orders,
    DayMetrics? metrics,
    List<ProductSalesEntry>? topProducts,
    List<TopClienteRow>? topClientes,
    bool? isClosed,
    String? error,
    String? closeMessage,
    String? closeError,
  }) {
    return DailyCloseState(
      isLoading: isLoading ?? this.isLoading,
      date: date ?? this.date,
      orders: orders ?? this.orders,
      metrics: metrics ?? this.metrics,
      topProducts: topProducts ?? this.topProducts,
      topClientes: topClientes ?? this.topClientes,
      isClosed: isClosed ?? this.isClosed,
      error: error,
      closeMessage: closeMessage,
      closeError: closeError,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dailyCloseProvider =
    NotifierProvider<DailyCloseNotifier, DailyCloseState>(
  () => DailyCloseNotifier(),
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DailyCloseNotifier extends Notifier<DailyCloseState> {
  AppDatabase get _db => AppDatabase.instance;

  @override
  DailyCloseState build() => const DailyCloseState();

  /// Carga el día [dateIso] (`yyyy-MM-dd`); `null` → hoy.
  Future<void> loadDay(String? dateIso) async {
    state = const DailyCloseState(isLoading: true);
    try {
      final date = dateIso ?? todayIso();
      final orders =
          await ref.read(orderRepositoryProvider).getOrdersByDay(date);

      // Costos por código corto: la spec inyecta el costo de producción
      // desde Products (computeDayMetrics es puro).
      final products = await _getAllProducts();
      final costByProduct = <String, double>{
        for (final p in products)
          if (p.codigoCorto != null) p.codigoCorto!: p.costPrice,
      };

      final metrics = computeDayMetrics(orders, date, costByProduct);
      final summary =
          await ref.read(dailyCloseDatasourceProvider).getSummary(date);

      state = DailyCloseState(
        date: date,
        orders: orders,
        metrics: metrics,
        topProducts: _topProductsOf(orders, date),
        topClientes: await _resolveTopClientes(metrics.topClientes),
        isClosed: summary != null,
      );
    } catch (e) {
      state = DailyCloseState(error: 'Error al cargar el día: $e');
    }
  }

  /// Cierra el día cargado como [actorRole].
  ///
  /// La capa de datos rechaza cualquier rol que no sea `admin`
  /// (`StateError` sin escribir): la UI ya oculta el botón a no-admin,
  /// pero la defensa real vive en `closeDay`.
  Future<void> cerrarDia({required String actorRole}) async {
    final date = state.date;
    if (date == null || state.isClosed) return;
    try {
      await ref.read(dailyCloseDatasourceProvider).closeDay(
            dateIso: date,
            actorRole: actorRole,
            metrics: state.metrics,
            topClientesJson: encodeTopClientes(state.metrics.topClientes),
          );
      state = state.copyWith(
        isClosed: true,
        closeMessage: 'Día $date cerrado correctamente',
      );
    } catch (e) {
      state = state.copyWith(
        closeError: e is StateError
            ? e.message
            : 'No se pudo cerrar el día: $e',
      );
    }
  }

  Future<List<Product>> _getAllProducts() {
    return (_db.select(_db.products)
          ..where((p) => p.isDeleted.equals(false)))
        .get();
  }

  /// Desglose por producto (cantidad y monto) de los pedidos de venta del
  /// día, ordenado por cantidad descendente. Sin split por categoría.
  List<ProductSalesEntry> _topProductsOf(
    List<RestaurantOrder> orders,
    String date,
  ) {
    final quantity = <String, int>{};
    final amount = <String, double>{};
    for (final order in saleOrdersOfDay(orders, date)) {
      for (final item in order.items) {
        quantity[item.code] = (quantity[item.code] ?? 0) + item.qty;
        amount[item.code] = (amount[item.code] ?? 0) + item.subtotal;
      }
    }
    final sorted = quantity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in sorted)
        ProductSalesEntry(
          productCode: entry.key,
          quantity: entry.value,
          amount: amount[entry.key] ?? 0,
        ),
    ];
  }

  /// Resuelve los `clienteId` del ranking a nombre visible. Best-effort:
  /// sin clientes (o con ids huérfanos) se muestra el propio id.
  Future<List<TopClienteRow>> _resolveTopClientes(
    List<TopClienteEntry> entries,
  ) async {
    if (entries.isEmpty) return const [];
    Map<String, String> names;
    try {
      final clients = await ref.read(clientRepositoryProvider).getAllClients();
      names = {for (final c in clients) c.id: c.nombre};
    } catch (_) {
      names = const {};
    }
    return [
      for (final entry in entries)
        TopClienteRow(
          clienteId: entry.clienteId,
          nombre: names[entry.clienteId] ?? entry.clienteId,
          ventas: entry.ventas,
        ),
    ];
  }
}
