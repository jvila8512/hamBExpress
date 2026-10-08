import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/widgets/status_badge.dart';
import 'package:etecsa/config/theme/widgets/ticket_card.dart';
import 'package:etecsa/features/clients/domain/entities/restaurant_client.dart';
import 'package:etecsa/features/clients/presentation/providers/client_provider.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Order Edit Screen — spec: day-management / "Move an Order Between Days"
// ---------------------------------------------------------------------------
///
/// `/orders/edit/:id`: cambia SOLO `fechaPedido` del pedido existente
/// (`copyWith(fechaPedido:)`), de modo que estado, líneas, cliente y totales
/// quedan intactos y `fechaCreacion` conserva la marca de auditoría.

class OrderEditScreen extends ConsumerStatefulWidget {
  const OrderEditScreen({super.key, required this.orderId});

  /// Pedido a editar, desde `/orders/edit/:id`.
  final String orderId;

  @override
  ConsumerState<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends ConsumerState<OrderEditScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  RestaurantOrder? _order;
  RestaurantClient? _cliente;

  /// Día elegido con el date picker; null = aún sin elegir.
  DateTime? _nuevaFecha;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(orderRepositoryProvider).getOrderById(widget.orderId);
      if (order == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Pedido ${widget.orderId} no encontrado';
          _isLoading = false;
        });
        return;
      }
      RestaurantClient? cliente;
      try {
        cliente = await ref
            .read(clientRepositoryProvider)
            .getClientById(order.clienteId);
      } catch (_) {
        cliente = null;
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _cliente = cliente;
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

  String _toIso(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDay() async {
    final order = _order;
    if (order == null) return;
    final actual = DateTime.tryParse(order.fechaPedido) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nuevaFecha ?? actual,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Día del pedido',
    );
    if (picked == null || !mounted) return;
    setState(() => _nuevaFecha = picked);
  }

  /// Guarda el movimiento: solo cambia `fechaPedido`.
  Future<void> _save() async {
    final order = _order;
    final nueva = _nuevaFecha;
    if (order == null || nueva == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(orderRepositoryProvider).updateOrder(
            order.copyWith(fechaPedido: _toIso(nueva)),
          );
      if (!mounted) return;
      setState(() {
        _nuevaFecha = null;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Día actualizado')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

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
        title: const Text('Cambiar día'),
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
              Text(_error!, style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center),
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

    final order = _order;
    if (order == null) return const SizedBox.shrink();

    final fechaActual = order.fechaPedido;
    final nuevaIso = _nuevaFecha == null ? null : _toIso(_nuevaFecha!);
    final hayCambio = nuevaIso != null && nuevaIso != fechaActual;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Pedido ────────────────────────────────────────────────
        TicketCard(
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
              Text(
                'Cliente: ${_cliente?.nombre ?? order.clienteId}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Total: ',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.textSecondary)),
                  Text('\$${order.montoTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.accent)),
                ],
              ),
              if (order.items.isNotEmpty) ...[
                const Divider(height: 16),
                Text('Líneas: ${order.items.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Día actual / nuevo ────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DÍA ACTUAL',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(fechaActual,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(nuevaIso == null
                      ? 'Elegir día nuevo'
                      : 'Día nuevo: $nuevaIso'),
                ),
                if (nuevaIso != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Solo cambia el día: estado, líneas, cliente y totales '
                    'se conservan; la fecha de creación no se modifica.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Guardar ───────────────────────────────────────────────
        FilledButton.icon(
          onPressed: hayCambio && !_isSaving ? _save : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: const Text('Guardar día'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/days/$fechaActual');
              }
            },
            child: const Text('Volver'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
