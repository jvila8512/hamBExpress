import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/config/theme/app_colors.dart';

/// A colored pill badge that represents an [OrderState].
///
/// Fixed palette mapping (role-flows delta) — the same three hex values
/// in both themes:
/// - `pedido`     → Achiote `#D9531E` — created, pending confirmation
/// - `confirmado` → Mostaza `#E4A22E` — confirmed, in progress
/// - `recogido`   → Mojo `#7C9A3B` — picked up (terminal)
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
  ///
  /// The role-flows delta pins the three palette hexes for BOTH themes:
  /// Achiote `#D9531E`, Mostaza `#E4A22E`, Mojo `#7C9A3B`.
  /// [brightness] is kept for caller compatibility but does not change
  /// the badge palette.
  static Color colorFor(OrderState state, {required Brightness brightness}) {
    switch (state) {
      case OrderState.pedido:
        return AppColors.accent; // Achiote #D9531E
      case OrderState.confirmado:
        return AppColors.warningDark; // Mostaza #E4A22E
      case OrderState.recogido:
        return AppColors.successDark; // Mojo #7C9A3B
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
