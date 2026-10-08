import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/daily_close/presentation/providers/daily_close_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Daily Close Screen — spec: daily-close
// ---------------------------------------------------------------------------
///
/// Cierre del día para un día ARBITRARIO (`/daily-close?date=`, por defecto
/// hoy). Una sola vista, SIN tabs:
/// - Ventas del día con desglose por producto (sin split sólidos/líquidos).
/// - Costo de producción y Ganancias con distribución 30/30/40.
/// - Top de clientes (ranking por ventas).
/// - "Cerrar día" (solo admin; la capa de datos también rechaza a otros).
///
/// Los bloques manuales (Gastos, Compras, Nómina) y el desglose EF-TR ya
/// no existen: la spec los elimina.

class DailyCloseScreen extends ConsumerStatefulWidget {
  const DailyCloseScreen({super.key, this.date});

  /// Día a cerrar (`yyyy-MM-dd`), query param `date` de `/daily-close`.
  /// `null` → hoy.
  final String? date;

  @override
  ConsumerState<DailyCloseScreen> createState() => _DailyCloseScreenState();
}

class _DailyCloseScreenState extends ConsumerState<DailyCloseScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _date;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _date = widget.date ?? todayIso();
    _loadRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyCloseProvider.notifier).loadDay(_date);
    });
  }

  Future<void> _loadRole() async {
    try {
      final role =
          await const FlutterSecureStorage().read(key: 'user_role') ?? '';
      if (mounted) setState(() => _userRole = role);
    } catch (_) {
      // Sin storage no se muestra la acción de cierre; la capa de datos
      // igual solo acepta 'admin'.
    }
  }

  Future<void> _reload() =>
      ref.read(dailyCloseProvider.notifier).loadDay(_date);

  Future<void> _pickDay() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      helpText: 'Día a cerrar',
    );
    if (picked == null || !mounted) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    setState(() => _date = '${picked.year}-$month-$day');
    await ref.read(dailyCloseProvider.notifier).loadDay(_date);
  }

  Future<void> _cerrarDia() =>
      ref.read(dailyCloseProvider.notifier).cerrarDia(actorRole: _userRole);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyCloseProvider);
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);

    // Cierre aceptado / rechazado → aviso único por cambio.
    ref.listen(dailyCloseProvider, (previous, next) {
      if (next.closeMessage != null &&
          next.closeMessage != previous?.closeMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.closeMessage!)),
        );
      }
      if (next.closeError != null &&
          next.closeError != previous?.closeError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.closeError!)),
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Cierre del Día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Elegir día',
            onPressed: state.isLoading ? null : _pickDay,
          ),
          if (state.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: state.isLoading ? null : _reload,
          ),
        ],
      ),
      body: _buildBody(state, colors, theme),
    );
  }

  Widget _buildBody(
    DailyCloseState state,
    AppColorsTheme colors,
    ThemeData theme,
  ) {
    if (state.isLoading && state.date == null) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }
    if (state.error != null && state.date == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: colors.danger.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text('Error al cargar el día', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dayCard(state, colors, theme),
        const SizedBox(height: 16),
        _salesCard(state, colors, theme),
        const SizedBox(height: 16),
        _costCard(state, colors, theme),
        const SizedBox(height: 16),
        _profitCard(state, colors, theme),
        const SizedBox(height: 16),
        _topClientesCard(state, colors, theme),
        const SizedBox(height: 16),
        _closeSection(state, colors, theme),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── DÍA ──────────────────────────────────────────────────────────

  Widget _dayCard(DailyCloseState state, AppColorsTheme colors, ThemeData theme) {
    final cerrado = state.isClosed;
    final statusColor = cerrado ? colors.success : colors.accent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('DÍA SELECCIONADO',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              state.date ?? _date,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    cerrado ? 'Cerrado' : 'Abierto',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Total pedidos: ${state.orders.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── VENTAS + DESGLOSE POR PRODUCTO ───────────────────────────────

  Widget _salesCard(DailyCloseState state, AppColorsTheme colors, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('VENTAS TOTALES',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              '\$${state.metrics.ventas.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('PRODUCTOS DEL DÍA',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary, letterSpacing: 1)),
            ),
            const SizedBox(height: 8),
            if (state.topProducts.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('No hay productos vendidos este día.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary)),
              )
            else
              for (final entry in state.topProducts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('${entry.quantity}x',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.accent)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.productCode,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('\$${entry.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ─── COSTO ────────────────────────────────────────────────────────

  Widget _costCard(DailyCloseState state, AppColorsTheme colors, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('COSTO DE PRODUCCIÓN',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              '\$${state.metrics.costoProduccion.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── GANANCIAS 30/30/40 ───────────────────────────────────────────

  Widget _profitCard(DailyCloseState state, AppColorsTheme colors, ThemeData theme) {
    final metrics = state.metrics;

    Widget shareRow(String label, String pct, double amount) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 8),
            Text(pct,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary)),
            const Spacer(),
            Text('\$${amount.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GANANCIAS',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              '\$${metrics.ganancias.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: colors.success,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text('DISTRIBUCIÓN',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 4),
            shareRow('Yurdenis', '(30%)', metrics.yurdenis),
            shareRow('Mildrey', '(30%)', metrics.mildrey),
            shareRow('Reinversión', '(40%)', metrics.reinversion),
          ],
        ),
      ),
    );
  }

  // ─── TOP DE CLIENTES ──────────────────────────────────────────────

  Widget _topClientesCard(DailyCloseState state, AppColorsTheme colors, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOP DE CLIENTES',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 12),
            if (state.topClientes.isEmpty)
              Text('Sin ventas registradas este día.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary))
            else
              for (var i = 0; i < state.topClientes.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('${i + 1}. ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary)),
                      Expanded(
                        child: Text(
                          state.topClientes[i].nombre,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${state.topClientes[i].ventas.toStringAsFixed(2)}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.accent),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ─── CERRAR DÍA ───────────────────────────────────────────────────

  Widget _closeSection(DailyCloseState state, AppColorsTheme colors, ThemeData theme) {
    // Solo admin ve la acción (la capa de datos rechaza a otros roles
    // aunque se invoque de otra forma).
    if (_userRole != 'admin') return const SizedBox.shrink();

    if (state.isClosed) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.lock, color: colors.success),
          title: const Text('Día cerrado'),
          subtitle: Text(
            'El cierre de ${state.date ?? _date} ya está guardado.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: state.isLoading ? null : _cerrarDia,
      icon: const Icon(Icons.event_available, size: 18),
      label: const Text('Cerrar día'),
    );
  }
}
