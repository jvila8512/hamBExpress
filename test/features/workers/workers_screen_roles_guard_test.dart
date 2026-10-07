import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// role-flows: the workers screen MUST assign, display, default and filter
/// only the two surviving roles (`admin`, `vendedor`).
///
/// Source guard — same test layer as `license_strip_guard_test.dart`. The
/// screen is a `ConsumerStatefulWidget` wired to `AppDatabase.instance` and
/// `flutter_secure_storage` with no injection seam, so its role options are
/// pinned where they are declared instead of through widget pumping (mock
/// count would dwarf the assertions).
void main() {
  final src = File(
    'lib/features/workers/presentation/screens/workers_screen.dart',
  ).readAsStringSync();

  List<String> quotedList(String pattern) {
    final match = RegExp(pattern, dotAll: true).firstMatch(src);
    expect(match, isNotNull, reason: 'declaration not found: $pattern');
    return RegExp(r"'([a-z_]+)'")
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
  }

  group('workers screen — two-role residue guard (role-flows)', () {
    test('_assignableRoles holds exactly admin and vendedor', () {
      expect(
        quotedList(r'_assignableRoles = \[(.*?)\];'),
        ['admin', 'vendedor'],
        reason: 'only the two surviving roles may be assigned',
      );
    });

    test('_roleLabels labels exactly admin and vendedor', () {
      expect(
        quotedList(r'_roleLabels = \{(.*?)\};'),
        ['admin', 'vendedor'],
        reason: 'the label map must declare only existing roles',
      );
    });

    test('no legacy role token survives in the screen', () {
      const legacyTokens = [
        'super_admin',
        'almacenero',
        'redes',
        'cocina',
        'mesero',
        'domicilio',
        'Redes',
        'Cocina',
        'Mesero',
        'Domicilio',
        'Super Admin',
      ];
      final offenders = <String>[
        for (final token in legacyTokens)
          if (src.contains(token)) token,
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'role-flows deletes these roles: $offenders',
      );
    });

    test('edit dialog falls back to a valid two-role value', () {
      final match = RegExp(
        r"_assignableRoles\.contains\(\s*user\.role\s*\)\s*\?\s*user\.role\s*:\s*'([a-z_]+)'",
      ).firstMatch(src);
      expect(
        match,
        isNotNull,
        reason: 'the edit dialog must keep its normalizing fallback',
      );
      expect(
        ['admin', 'vendedor'],
        contains(match!.group(1)),
        reason: 'the fallback default must be a role that still exists',
      );
    });
  });
}
