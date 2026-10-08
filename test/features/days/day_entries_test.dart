import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/features/days/presentation/providers/day_list_provider.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

// ---------------------------------------------------------------------------
// Lista de días — spec: day-management / "Day List".
// Tarea 6.3 (RED): `buildDayEntries` agrupa pedidos por fecha.
//   - Cuenta pedidos por día y marca abierto/cerrado según fechasCerradas.
//   - Más reciente primero; un día solo aparece si tiene pedidos O cierre.
// ---------------------------------------------------------------------------

RestaurantOrder _order(String id, String fecha, {String cliente = 'cli-1'}) {
  return RestaurantOrder(
    id: id,
    clienteId: cliente,
    estado: OrderState.recogido,
    creadoPorUsuarioId: 'u1',
    fechaPedido: fecha,
  );
}

void main() {
  group('buildDayEntries — agrupación por fecha', () {
    test('cuenta los pedidos de cada día', () {
      final entries = buildDayEntries(
        [
          _order('A-01', '2026-10-01'),
          _order('B-01', '2026-10-01'),
          _order('C-01', '2026-10-01'),
          _order('D-01', '2026-10-02'),
        ],
        const {},
      );

      expect(entries, hasLength(2));
      final dia1 = entries.firstWhere((e) => e.fecha == '2026-10-01');
      final dia2 = entries.firstWhere((e) => e.fecha == '2026-10-02');
      expect(dia1.orderCount, 3);
      expect(dia2.orderCount, 1);
    });

    test('ordena del día más reciente al más antiguo', () {
      final entries = buildDayEntries(
        [
          _order('A-01', '2026-09-30'),
          _order('B-01', '2026-10-02'),
          _order('C-01', '2026-10-01'),
        ],
        const {},
      );

      expect(
        entries.map((e) => e.fecha).toList(),
        ['2026-10-02', '2026-10-01', '2026-09-30'],
      );
    });

    test('marca cerrado/abierto según las fechas con cierre persistido', () {
      final entries = buildDayEntries(
        [
          _order('A-01', '2026-10-01'),
          _order('B-01', '2026-10-02'),
        ],
        {'2026-10-01'},
      );

      expect(entries.firstWhere((e) => e.fecha == '2026-10-01').cerrado, isTrue);
      expect(entries.firstWhere((e) => e.fecha == '2026-10-02').cerrado, isFalse);
    });

    test('un día cerrado sin pedidos igual aparece (cierre persistido)', () {
      final entries = buildDayEntries(
        [_order('A-01', '2026-10-02')],
        {'2026-10-01'},
      );

      expect(entries.map((e) => e.fecha), contains('2026-10-01'));
      final cerrado = entries.firstWhere((e) => e.fecha == '2026-10-01');
      expect(cerrado.orderCount, 0);
      expect(cerrado.cerrado, isTrue);
    });

    test('no fabrica días: sin pedidos y sin cierre no aparece', () {
      final entries = buildDayEntries(
        [_order('A-01', '2026-10-02')],
        const {},
      );

      // No se rellena el calendario: solo el día con actividad.
      expect(entries.map((e) => e.fecha).toList(), ['2026-10-02']);
    });

    test('sin pedidos ni cierres → lista vacía (estado vacío)', () {
      expect(buildDayEntries(const [], const {}), isEmpty);
    });
  });
}
