import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:etecsa/config/router/app_router.dart';
import 'package:etecsa/features/daily_close/presentation/screens/daily_close_screen.dart';
import 'package:etecsa/features/days/presentation/screens/day_detail_screen.dart';
import 'package:etecsa/features/days/presentation/screens/day_list_screen.dart';
import 'package:etecsa/features/days/presentation/screens/order_edit_screen.dart';

// ---------------------------------------------------------------------------
// Rutas de días — spec: day-management (Day List / Open a Day / Move an Order)
// Tarea 6.3 (RED): registra `/days`, `/days/:date`, `/orders/edit/:id` y
// plumbea el parámetro de día a cada pantalla.
//   - `/days` construye DayListScreen (los menús ya enlazan a esta ruta).
//   - `/days/:date` entrega el `date` al DayDetailScreen.
//   - `/orders/edit/:id` entrega el `id` al OrderEditScreen.
//   - `/daily-close?date=D` entrega el query param al DailyCloseScreen.
// ---------------------------------------------------------------------------

/// Matchea [location] contra la configuración real del router y construye el
/// widget de la ruta encontrada.
Future<Widget> _buildForLocation(WidgetTester tester, String location) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  final matchList = appRouter.configuration.findMatch(Uri.parse(location));
  expect(
    matchList.isError,
    isFalse,
    reason: '$location debe hacer match en appRouter',
  );

  final match = matchList.matches.single;
  final state = match.buildState(appRouter.configuration, matchList);
  final route = match.route as GoRoute;
  return route.builder!(ctx, state);
}

void main() {
  testWidgets('/days construye la pantalla de lista de días', (tester) async {
    final widget = await _buildForLocation(tester, '/days');

    expect(widget, isA<DayListScreen>());
  });

  testWidgets('/days/:date hace match y entrega el date al DayDetailScreen',
      (tester) async {
    final widget = await _buildForLocation(tester, '/days/2026-10-02');

    expect(widget, isA<DayDetailScreen>());
    expect((widget as DayDetailScreen).date, '2026-10-02');
  });

  testWidgets('/days/:date entrega otra fecha distinta sin mezclar días',
      (tester) async {
    final widget = await _buildForLocation(tester, '/days/2026-10-01');

    expect((widget as DayDetailScreen).date, '2026-10-01');
  });

  testWidgets('/orders/edit/:id hace match y entrega el id al OrderEditScreen',
      (tester) async {
    final widget = await _buildForLocation(tester, '/orders/edit/A1-1002-001');

    expect(widget, isA<OrderEditScreen>());
    expect((widget as OrderEditScreen).orderId, 'A1-1002-001');
  });

  testWidgets('/daily-close?date=D plumbea el query param a la pantalla',
      (tester) async {
    final widget = await _buildForLocation(
      tester,
      '/daily-close?date=2026-10-01',
    );

    expect(widget, isA<DailyCloseScreen>());
    expect((widget as DailyCloseScreen).date, '2026-10-01');
  });

  testWidgets('/daily-close sin query deja date en null (usa hoy)',
      (tester) async {
    final widget = await _buildForLocation(tester, '/daily-close');

    expect(widget, isA<DailyCloseScreen>());
    expect((widget as DailyCloseScreen).date, isNull);
  });

  testWidgets('una ruta que no existe no hace match (typo /dias)',
      (tester) async {
    tester.pumpWidget(
      const MaterialApp(home: SizedBox.shrink()),
    );

    final matchList = appRouter.configuration.findMatch(Uri.parse('/dias'));

    expect(matchList.isError, isTrue);
  });
}
