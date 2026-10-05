import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level schema tests for schema v16.
///
/// These read `app_database.dart` as text instead of exercising the Drift DSL
/// at runtime: calling `table.primaryKey`/column getters outside the generated
/// code throws `Unsupported operation: This method should not be called at
/// runtime` (the DSL `primaryKey` trap), which is why the v14 versions of these
/// tests were permanently red.
void main() {
  final dbSrc = File('lib/core/database/app_database.dart').readAsStringSync();

  group('schema v16 table definitions', () {
    test('schemaVersion is 16', () {
      expect(
        dbSrc.contains('int get schemaVersion => 16'),
        isTrue,
        reason: 'v16 must be declared so the one-shot migration runs',
      );
    });

    test('RestaurantOrders declares fecha_pedido and v16 adds it', () {
      final ordersTable = RegExp(
        r'class RestaurantOrders extends Table \{(.*?)\n\}',
        dotAll: true,
      ).firstMatch(dbSrc);
      expect(ordersTable, isNotNull,
          reason: 'RestaurantOrders must remain a declared table');
      expect(
        ordersTable!.group(1)!.contains('TextColumn get fechaPedido'),
        isTrue,
        reason: 'the business-day column (SQL fecha_pedido) must be declared',
      );
      expect(
        dbSrc
            .contains('addColumn(restaurantOrders, restaurantOrders.fechaPedido)'),
        isTrue,
        reason: 'v16 must addColumn fecha_pedido when upgrading',
      );
    });

    test('DailySummaries declares topClientesJson and v16 adds it', () {
      final summariesTable = RegExp(
        r'class DailySummaries extends Table \{(.*?)\n\}',
        dotAll: true,
      ).firstMatch(dbSrc);
      expect(summariesTable, isNotNull,
          reason: 'DailySummaries must remain a declared table');
      expect(
        summariesTable!.group(1)!.contains('TextColumn get topClientesJson'),
        isTrue,
        reason: 'the top-clients cache column must be declared',
      );
      expect(
        dbSrc.contains(
            'addColumn(dailySummaries, dailySummaries.topClientesJson)'),
        isTrue,
        reason: 'v16 must addColumn topClientesJson when upgrading',
      );
    });

    test('preserved tables stay registered under a v16 migration branch', () {
      for (final table in ['Users', 'RestaurantClients', 'Products']) {
        expect(
          dbSrc.contains('class $table extends Table'),
          isTrue,
          reason: '$table must survive the v16 migration',
        );
        expect(
          dbSrc.contains('    $table,'),
          isTrue,
          reason: '$table must stay registered in @DriftDatabase',
        );
      }
      expect(
        dbSrc.contains('if (from < 16)'),
        isTrue,
        reason: 'the v16 migration branch must exist',
      );
    });
  });
}
