import 'package:drift/drift.dart';

import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/daily_close/domain/day_metrics.dart';

/// Drift datasource del cierre de día sobre `DailySummaries` (PK `fecha`).
class DailyCloseDatasource {
  final AppDatabase _db;

  DailyCloseDatasource(this._db);

  /// Persiste el cierre de [dateIso] con las [metrics] calculadas.
  ///
  /// Guard de rol en la capa de datos: solo `admin` puede cerrar; cualquier
  /// otro rol lanza [StateError] **antes** de tocar la base (defensa en
  /// profundidad — la UI ya oculta la acción a no-admin).
  ///
  /// Es un upsert por PK: re-cerrar la misma fecha actualiza el registro
  /// sin duplicarlo (cerrado = fila existente).
  Future<void> closeDay({
    required String dateIso,
    required String actorRole,
    required DayMetrics metrics,
    required String topClientesJson,
  }) async {
    if (actorRole != 'admin') {
      throw StateError(
        'Solo admin puede cerrar el día (rol recibido: $actorRole)',
      );
    }

    await _db.into(_db.dailySummaries).insert(
      DailySummariesCompanion.insert(
        fecha: dateIso,
        totalVentas: Value(metrics.ventas),
        costoProduccion: Value(metrics.costoProduccion),
        utilidadNeta: Value(metrics.ganancias),
        distribucionYurdenis: Value(metrics.yurdenis),
        distribucionMildrey: Value(metrics.mildrey),
        distribucionNegocio: Value(metrics.reinversion),
        topClientesJson: Value(topClientesJson),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Resumen guardado de [dateIso] o `null` si el día sigue abierto.
  Future<DailySummary?> getSummary(String dateIso) {
    return (_db.select(_db.dailySummaries)
          ..where((summary) => summary.fecha.equals(dateIso)))
        .getSingleOrNull();
  }

  /// Todos los cierres guardados (alimenta la lista de días).
  Future<List<DailySummary>> getAllSummaries() {
    return _db.select(_db.dailySummaries).get();
  }
}
