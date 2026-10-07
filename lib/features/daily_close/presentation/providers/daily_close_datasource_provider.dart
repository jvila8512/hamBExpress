import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/daily_close/infrastructure/daily_close_datasource.dart';

/// Fuente de [DailyCloseDatasource] sobre la instancia singleton de la BD.
///
/// En tests se sobreescribe con `AppDatabase.forTesting(...)` para trabajar
/// en memoria.
final dailyCloseDatasourceProvider = Provider<DailyCloseDatasource>((ref) {
  return DailyCloseDatasource(AppDatabase.instance);
});
