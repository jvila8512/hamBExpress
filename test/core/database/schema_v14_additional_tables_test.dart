import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level v16 legacy-cleanup tests (counterpart of `schema_v14_test.dart`).
///
/// Read as text on purpose: instantiating Drift table classes from the DSL at
/// runtime throws `Unsupported operation: This method should not be called at
/// runtime`, the trap that kept the v14 versions of these tests red.
void main() {
  final dbSrc = File('lib/core/database/app_database.dart').readAsStringSync();

  group('schema v16 - legacy cleanup', () {
    test('the 7 dead feature tables are dropped and undeclared', () {
      const deadTables = <String>[
        'trusted_contacts',
        'sms_messages',
        'order_state_history',
        'restaurant_tables',
        'daily_expenses',
        'daily_purchases',
        'daily_payroll',
      ];
      const deadClasses = <String>[
        'TrustedContacts',
        'SmsMessages',
        'OrderStateHistory',
        'RestaurantTables',
        'DailyExpenses',
        'DailyPurchases',
        'DailyPayroll',
      ];
      for (final table in deadTables) {
        expect(
          dbSrc.contains('DROP TABLE IF EXISTS $table'),
          isTrue,
          reason: 'v16 must drop the physical table $table',
        );
      }
      for (final cls in deadClasses) {
        expect(
          dbSrc.contains('class $cls extends Table'),
          isFalse,
          reason: '$cls must no longer be declared',
        );
        expect(
          dbSrc.contains('    $cls,'),
          isFalse,
          reason: '$cls must no longer be registered in @DriftDatabase',
        );
      }
    });

    test('legacy orders are truncated and POS order tables dropped', () {
      expect(
        dbSrc.contains('DELETE FROM restaurant_orders'),
        isTrue,
        reason: 'v16 must truncate legacy restaurant order headers',
      );
      expect(
        dbSrc.contains('DELETE FROM restaurant_order_items'),
        isTrue,
        reason: 'v16 must truncate legacy restaurant order lines',
      );
      expect(
        dbSrc.contains('DROP TABLE IF EXISTS orders'),
        isTrue,
        reason: 'the unused POS orders table must be dropped',
      );
      expect(
        dbSrc.contains('DROP TABLE IF EXISTS order_items'),
        isTrue,
        reason: 'the unused POS order_items table must be dropped',
      );
    });

    test(
        'roles remap through a logged 8-value CASE and an admin seed '
        'guarded by an empty Users table', () {
      const legacyRoles = <String>[
        'super_admin',
        'admin',
        'redes',
        'cocina',
        'mesero',
        'domicilio',
        'almacenero',
        'vendedor',
      ];
      expect(
        dbSrc.contains('CASE role'),
        isTrue,
        reason: 'the remap must be a single idempotent CASE statement',
      );
      for (final role in legacyRoles) {
        expect(
          dbSrc.contains("WHEN '$role'"),
          isTrue,
          reason: "the remap must cover the legacy role '$role'",
        );
      }
      expect(
        dbSrc.contains("ELSE 'vendedor'"),
        isTrue,
        reason: 'no stored role outside {admin, vendedor} may remain',
      );
      expect(
        dbSrc.contains('v16 role remap'),
        isTrue,
        reason: 'the migration must log the mapping',
      );
      expect(
        dbSrc.contains('Future<void> _seedAdminIfEmpty()'),
        isTrue,
        reason: 'the default-admin seed must exist',
      );
      expect(
        dbSrc.contains('await _seedAdminIfEmpty();'),
        isTrue,
        reason: 'the seed must run during database initialization',
      );
      expect(
        dbSrc.contains('if (existing.isNotEmpty) return;'),
        isTrue,
        reason: 'the seed must never run when a user already exists',
      );
    });
  });
}
