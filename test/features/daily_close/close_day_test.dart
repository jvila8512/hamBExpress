import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/daily_close/domain/day_metrics.dart';
import 'package:etecsa/features/daily_close/infrastructure/daily_close_datasource.dart';

// ---------------------------------------------------------------------------
// Cierre de día — spec: day-management / "Day Close" + daily-close admin-only.
// Tarea 6.1 (RED): contrato de `DailyCloseDatasource.closeDay`.
//   - Guard de rol EN la capa de datos: solo 'admin' escribe; cualquier otro
//     rol lanza StateError sin tocar la base.
//   - Un único registro por fecha (PK fecha, upsert): re-cerrar actualiza.
//   - getSummary/getAllSummaries alimentan la lista de días.
// ---------------------------------------------------------------------------

DayMetrics _metrics({double ventas = 100, double costo = 40}) =>
    DayMetrics(ventas: ventas, costoProduccion: costo);

Future<int> _rowsForDate(AppDatabase db, String fecha) async {
  final rows = await (db.select(db.dailySummaries)
        ..where((t) => t.fecha.equals(fecha)))
      .get();
  return rows.length;
}

void main() {
  late AppDatabase db;
  late DailyCloseDatasource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = DailyCloseDatasource(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('closeDay — guard de rol en la capa de datos', () {
    test('un vendedor no puede cerrar: StateError y no escribe ningún '
        'registro', () async {
      await expectLater(
        ds.closeDay(
          dateIso: '2026-10-02',
          actorRole: 'vendedor',
          metrics: _metrics(),
          topClientesJson: '[]',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _rowsForDate(db, '2026-10-02'), 0);
      expect(await ds.getSummary('2026-10-02'), isNull);
    });

    test('un rol distinto de admin también queda rechazado', () async {
      await expectLater(
        ds.closeDay(
          dateIso: '2026-10-02',
          actorRole: 'super_admin',
          metrics: _metrics(),
          topClientesJson: '[]',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _rowsForDate(db, '2026-10-02'), 0);
    });

    test('sin sesión (rol vacío) tampoco cierra el día', () async {
      await expectLater(
        ds.closeDay(
          dateIso: '2026-10-02',
          actorRole: '',
          metrics: _metrics(),
          topClientesJson: '[]',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _rowsForDate(db, '2026-10-02'), 0);
    });
  });

  group('closeDay — admin persiste el cierre', () {
    test('el admin guarda exactamente un registro con ventas, ganancias y '
        'top clientes', () async {
      await ds.closeDay(
        dateIso: '2026-10-02',
        actorRole: 'admin',
        metrics: _metrics(ventas: 100, costo: 40),
        topClientesJson: '[{"clienteId":"cli-1","ventas":100.0}]',
      );

      expect(await _rowsForDate(db, '2026-10-02'), 1);
      final row = (await ds.getSummary('2026-10-02'))!;
      expect(row.fecha, '2026-10-02');
      expect(row.totalVentas, 100.0);
      expect(row.costoProduccion, 40.0);
      expect(row.utilidadNeta, 60.0);
      expect(row.distribucionYurdenis, closeTo(18.0, 0.001));
      expect(row.distribucionMildrey, closeTo(18.0, 0.001));
      expect(row.distribucionNegocio, closeTo(24.0, 0.001));
      expect(row.topClientesJson, '[{"clienteId":"cli-1","ventas":100.0}]');
    });

    test('re-cerrar la misma fecha actualiza el registro sin duplicarlo',
        () async {
      await ds.closeDay(
        dateIso: '2026-10-02',
        actorRole: 'admin',
        metrics: _metrics(ventas: 100, costo: 40),
        topClientesJson: '[]',
      );
      await ds.closeDay(
        dateIso: '2026-10-02',
        actorRole: 'admin',
        metrics: _metrics(ventas: 250, costo: 90),
        topClientesJson: '[]',
      );

      expect(await _rowsForDate(db, '2026-10-02'), 1);
      final row = (await ds.getSummary('2026-10-02'))!;
      expect(row.totalVentas, 250.0);
      expect(row.costoProduccion, 90.0);
      expect(row.utilidadNeta, 160.0);
    });

    test('un día sin cerrar devuelve null (sigue abierto)', () async {
      expect(await ds.getSummary('2026-10-05'), isNull);
    });

    test('getAllSummaries expone todas las fechas cerradas para la lista '
        'de días', () async {
      await ds.closeDay(
        dateIso: '2026-10-01',
        actorRole: 'admin',
        metrics: _metrics(ventas: 80, costo: 30),
        topClientesJson: '[]',
      );
      await ds.closeDay(
        dateIso: '2026-10-02',
        actorRole: 'admin',
        metrics: _metrics(ventas: 120, costo: 50),
        topClientesJson: '[]',
      );

      final all = await ds.getAllSummaries();

      expect(all.map((r) => r.fecha), containsAll(['2026-10-01', '2026-10-02']));
      expect(all, hasLength(2));
    });
  });
}
