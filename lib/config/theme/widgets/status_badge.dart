import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/config/theme/app_colors.dart';

/// A colored pill badge that represents an [OrderState].
///
/// Color mapping for the three-state machine:
/// - `pedido`    → warning (Mostaza) — created, pending confirmation
/// - `confirmado` → accent (Achiote) — confirmed, in progress
/// - `recogido`  → success (Mojo) — picked up (terminal)
class StatusBadge extends StatelessWidget {
  final OrderState state;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.state,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  /// Resolves the display label for each [OrderState].
  static String labelFor(OrderState state) {
    switch (state) {
      case OrderState.pedido:
        return 'Pedido';
      case OrderState.confirmado:
        return 'Confirmado';
      case OrderState.recogido:
        return 'Recogido';
    }
  }

  /// Resolves the background color for each [OrderState].
  static Color colorFor(OrderState state, {required Brightness brightness}) {
    switch (state) {
      case OrderState.pedido:
        return AppColors.forBrightness(brightness).warning;
      case OrderState.confirmado:
        return AppColors.accent;
      case OrderState.recogido:
        return AppColors.forBrightness(brightness).success;
    }
  }

  /// Resolves the foreground (text) color for each [OrderState].
  static Color textColorFor(OrderState state, {required Brightness brightness}) {
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = colorFor(state, brightness: brightness);
    final fgColor = textColorFor(state, brightness: brightness);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100), // fully rounded pill
      ),
      child: Text(
        labelFor(state),
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: fgColor,
          height: 1.2,
        ),
      ),
    );
  }
}
