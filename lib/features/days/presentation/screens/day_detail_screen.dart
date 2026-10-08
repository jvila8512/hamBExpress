import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/widgets/status_badge.dart';
import 'package:etecsa/config/theme/widgets/ticket_card.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/daily_close/domain/day_metrics.dart';
import 'package:etecsa/features/daily_close/presentation/providers/daily_close_datasource_provider.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/orders/presentation/widgets/order_row_actions.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Day Detail Screen — spec: day-management / "Open a Day and View Its Orders"
// ---------------------------------------------------------------------------
///
/// Muestra solo los pedidos de [date] (nombre de cliente, estado y total por
/// fila), el cierre persistido del día si existe (ventas, ganancias, top de
/// clientes) y, para `admin` con el día abierto, la acción "Cerrar día"
/// hacia `/daily-close?date=`. Ambos roles pueden leer (Day Access by Role).

class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  /// Día a mostrar (`yyyy-MM-dd`), desde `/days/:date`.
  final String date;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  String? _error;
  List<RestaurantOrder> _orders = const [];
  Map<String, String> _nameByClientId = const {};
  Map<String, String> _cellByClientId = const {};

  // Cierre persistido del día (DailySummaries), si existe.
  bool _cerrado = false;
  double _ventasCerradas = 0;
  double _costoCerrado = 0;
  double _gananciasCerradas = 0;
  List<TopClienteEntry> _topClientesCerrado = const [];

  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
  }

  Future<void> _loadRole() async {
    try {
      final role =
          await const FlutterSecureStorage().read(key: 'user_role') ?? '';
      if (mounted) setState(() => _userRole = role);
    } catch (_) {
      // Sin storage no se muestra la acción de cierre (la capa de datos
      // igual rechaza a cualquier rol que no sea admin).
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final orders = await ref
          .read(orderRepositoryProvider)
          .getOrdersByDay(widget.date);
      final clients = await _loadClients();
      final summary = await ref
          .read(dailyCloseDatasourceProvider)
          .getSummary(widget.date);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _nameByClientId = {for (final c in clients) c.id: c.nombre};
        _cellByClientId = {for (final c in clients) c.id: c.telefono};
        _cerrado = summary != null;
        _ventasCerradas = summary?.totalVentas ?? 0;
        _costoCerrado = summary?.costoProduccion ?? 0;
        _gananciasCerradas = summary?.utilidadNeta ?? 0;
        _topClientesCerrado = decodeTopClientes(summary?.topClientesJson);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  /// `clienteId` → nombre/teléfono. Best-effort: sin clientes el nombre
  /// queda como `clienteId` y las acciones de contacto se deshabilitan.
  Future<List<RestaurantClient>> _loadClients() async {
    try {
      return await ref.read(clientRepositoryProvider).getAllClients();
    } catch (_) {
      return const [];
    }
  }

  /// Avanza el estado (`pedido` → `confirmado` → `recogido`) y recarga.
  Future<void> _advanceState(RestaurantOrder order, OrderState next) async {
    try {
      await ref.read(orderRepositoryProvider).updateOrderState(order.id, next);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  String get _title => widget.date;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(colors, theme),
    );
  }

  Widget _buildBody(AppColorsTheme colors, ThemeData theme) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: colors.danger.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text('No se pudo cargar el día',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: colors.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Cierre del día (persistido o acción de cierre) ──────
          _buildCloseSection(colors, theme),
          const SizedBox(height: 16),

          // ── Pedidos del día ─────────────────────────────────────
          _buildOrdersSection(colors, theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── CIERRE ───────────────────────────────────────────────────────

  Widget _buildCloseSection(AppColorsTheme colors, ThemeData theme) {
    if (_cerrado) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock, size: 18, color: colors.success),
                  const SizedBox(width: 8),
                  Text('CIERRE DEL DÍA',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary, letterSpacing: 1)),
                  const Spacer(),
                  Text('Cerrado',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.success, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              _moneyRow(colors, theme, 'Ventas', _ventasCerradas),
              const SizedBox(height: 6),
              _moneyRow(colors, theme, 'Costo de producción', _costoCerrado),
              const SizedBox(height: 6),
              _moneyRow(colors, theme, 'Ganancias', _gananciasCerradas),
              const Divider(height: 20),
              Text('TOP DE CLIENTES',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary, letterSpacing: 1)),
              const SizedBox(height: 8),
              if (_topClientesCerrado.isEmpty)
                Text('Sin ventas registradas este día.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary))
              else
                for (var i = 0; i < _topClientesCerrado.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('${i + 1}. ',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: colors.textSecondary)),
                        Expanded(
                          child: Text(
                            _nameOf(_topClientesCerrado[i].clienteId),
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('\$${_topClientesCerrado[i].ventas.toStringAsFixed(2)}',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.accent)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    // Día abierto: solo admin ve la acción (la capa de datos también
    // rechaza a cualquier otro rol).
    if (_userRole != 'admin') return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CIERRE DEL DÍA',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text('El día sigue abierto.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/daily-close?date=${widget.date}'),
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Cerrar día'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(
      AppColorsTheme colors, ThemeData theme, String label, double amount) {
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text('\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary)),
      ],
    );
  }

  // ─── PEDIDOS ──────────────────────────────────────────────────────

  Widget _buildOrdersSection(AppColorsTheme colors, ThemeData theme) {
    if (_orders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: colors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('No hay pedidos este día',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PEDIDOS DEL DÍA (${_orders.length})',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.textSecondary, letterSpacing: 1)),
        const SizedBox(height: 8),
        for (final order in _orders) ...[
          _buildOrderCard(order, colors, theme),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildOrderCard(
    RestaurantOrder order,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    final nombre = _nameByClientId[order.clienteId] ?? order.clienteId;

    return TicketCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                order.id,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              StatusBadge(state: order.estado, fontSize: 11),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Cliente: $nombre',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (order.fechaCreacion != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yy HH:mm').format(order.fechaCreacion!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Total: ',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colors.textSecondary)),
              Text('\$${order.montoTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.accent)),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OrderRowActions(
                  order: order,
                  clientCell: _cellByClientId[order.clienteId] ?? '',
                  onAdvance: (next) => _advanceState(order, next),
                ),
              ),
              IconButton(
                tooltip: 'Cambiar día',
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                onPressed: () => context.push('/orders/edit/${order.id}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nameOf(String clienteId) =>
      _nameByClientId[clienteId] ?? clienteId;
}
