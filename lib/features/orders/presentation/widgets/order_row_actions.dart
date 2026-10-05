import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/order_state.dart';
import '../../domain/entities/restaurant_order.dart';

// ---------------------------------------------------------------------------
// Order Row Actions — spec: order-management / Requirement "Order Row Actions"
// Exactly three actions per row: SMS (`sms:<cell>?body=`), call (`tel:<cell>`)
// and the state button whose label follows the three-state machine.
// ---------------------------------------------------------------------------

/// Visible label of the state button for [state].
///
/// `pedido` → `Confirmar`, `confirmado` → `Marcar recogido`,
/// `recogido` → `Recogido` (terminal, inspect only).
String orderStateActionLabel(OrderState state) => switch (state) {
      OrderState.pedido => 'Confirmar',
      OrderState.confirmado => 'Marcar recogido',
      OrderState.recogido => 'Recogido',
    };

/// Next legal state of the three-state machine, or `null` when [state] is
/// terminal (`recogido` never transitions).
OrderState? nextOrderState(OrderState state) => switch (state) {
      OrderState.pedido => OrderState.confirmado,
      OrderState.confirmado => OrderState.recogido,
      OrderState.recogido => null,
    };

/// `sms:<cell>?body=<summary>` — opens the composer; the message is never
/// sent silently.
Uri buildSmsUri(String cell, String body) =>
    Uri(scheme: 'sms', path: cell, queryParameters: {'body': body});

/// `tel:<cell>` — opens the dialer with the number pre-filled.
Uri buildTelUri(String cell) => Uri(scheme: 'tel', path: cell);

class OrderRowActions extends StatelessWidget {
  const OrderRowActions({
    super.key,
    required this.order,
    this.clientCell = '',
    this.onAdvance,
    this.onInspect,
    this.launchExternal = launchUrl,
  });

  /// Order rendered in the row.
  final RestaurantOrder order;

  /// Client cell phone (`clienteId` → `RestaurantClients.telefono`).
  /// When empty the SMS/call actions are disabled.
  final String clientCell;

  /// Requests a state advance: `pedido` → `confirmado`,
  /// `confirmado` → `recogido`. Never called for the terminal state.
  final ValueChanged<OrderState>? onAdvance;

  /// The state button was tapped on a terminal order (inspect, no change).
  final VoidCallback? onInspect;

  /// Injectable intent launcher; defaults to [launchUrl].
  final Future<bool> Function(Uri uri) launchExternal;

  String get _orderSummary =>
      'Pedido ${order.id} · ${order.items.length} artículos · '
      '\$${order.montoTotal.toStringAsFixed(2)}';

  Future<void> _open(Uri uri) async {
    try {
      await launchExternal(uri);
    } catch (_) {
      // No SMS/dialer app available: keep the UI responsive.
    }
  }

  void _handleStatePressed() {
    final next = nextOrderState(order.estado);
    if (next == null) {
      onInspect?.call();
    } else {
      onAdvance?.call(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Enviar SMS',
          icon: const Icon(Icons.sms_outlined, size: 20),
          onPressed: clientCell.isEmpty
              ? null
              : () => _open(buildSmsUri(clientCell, _orderSummary)),
        ),
        IconButton(
          tooltip: 'Llamar',
          icon: const Icon(Icons.call_outlined, size: 20),
          onPressed: clientCell.isEmpty
              ? null
              : () => _open(buildTelUri(clientCell)),
        ),
        const Spacer(),
        FilledButton.tonal(
          onPressed: _handleStatePressed,
          child: Text(orderStateActionLabel(order.estado)),
        ),
      ],
    );
  }
}
