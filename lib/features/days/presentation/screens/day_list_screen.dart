import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/days/presentation/providers/day_list_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';

// ---------------------------------------------------------------------------
// Day List Screen — spec: day-management / "Day List with Counts and Status"
// ---------------------------------------------------------------------------
///
/// Cada fila muestra fecha, conteo de pedidos y estado abierto/cerrado.
/// Solo aparece un día con pedidos O cierre persistido (no se fabrica el
/// calendario), del más reciente al más antiguo. Alcanzable por ambos roles
/// (route guard: `/days` no es admin-only).

class DayListScreen extends ConsumerStatefulWidget {
  const DayListScreen({super.key});

  @override
  ConsumerState<DayListScreen> createState() => _DayListScreenState();
}

class _DayListScreenState extends ConsumerState<DayListScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _countLabel(int count) => count == 1 ? '1 pedido' : '$count pedidos';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final days = ref.watch(dayListProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Días'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => ref.invalidate(dayListProvider),
          ),
        ],
      ),
      body: days.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colors.danger.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text('No se pudieron cargar los días',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(dayListProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (entries) => entries.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 64,
                        color: colors.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay días con actividad',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Los días aparecen cuando tienen pedidos o un cierre guardado.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: Icon(
                      Icons.calendar_today_outlined,
                      color: entry.cerrado
                          ? colors.success
                          : colors.textSecondary,
                    ),
                    title: Text(
                      entry.fecha,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _countLabel(entry.orderCount),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                    trailing: _StatusTag(cerrado: entry.cerrado),
                    onTap: () => context.go('/days/${entry.fecha}'),
                  );
                },
              ),
      ),
    );
  }
}

/// Etiqueta de estado del día: `Cerrado` (cierre persistido) o `Abierto`.
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.cerrado});

  final bool cerrado;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forBrightness(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final color = cerrado ? colors.success : colors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        cerrado ? 'Cerrado' : 'Abierto',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
