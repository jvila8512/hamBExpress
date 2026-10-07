import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/core/database/app_database.dart';

/// role-flows / auth·Role mapping: the app has exactly two roles
/// (`admin`, `vendedor`).
///
/// `createDefaultAdmin` runs on every boot (splash flow and the first-login
/// retry), so it must never write a role outside the two-role set — doing so
/// would undo the v16 `_remapRolesToTwoRoles` migration on every launch.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> storedRoles() async {
    final users = await db.getAllUsers();
    return users.map((u) => u.role).toSet();
  }

  group('createDefaultAdmin — stays inside the two-role set', () {
    test('keeps the admin seeded by the v16 onCreate at role admin', () async {
      final seeded = await db.getUserByUsername('admin');
      expect(seeded, isNotNull, reason: 'onCreate seeds the default admin');
      expect(seeded!.role, 'admin');

      await db.createDefaultAdmin();

      final admin = await db.getUserByUsername('admin');
      expect(admin, isNotNull);
      expect(
        admin!.role,
        'admin',
        reason: 'boot must not undo the v16 role remap',
      );
      expect(
        await storedRoles(),
        everyElement(anyOf('admin', 'vendedor')),
        reason: 'no role outside the two-role set may ever be written',
      );
    });

    test('repairs an admin row stuck on a legacy role back to admin',
        () async {
      expect(await db.getUserByUsername('admin'), isNotNull);
      await db.customStatement(
        "UPDATE users SET role = 'redes' WHERE username = 'admin'",
      );

      await db.createDefaultAdmin();

      final admin = await db.getUserByUsername('admin');
      expect(admin!.role, 'admin');
      expect(await storedRoles(), everyElement(anyOf('admin', 'vendedor')));
    });

    test('creates the admin with role admin when no user exists', () async {
      await db.customStatement('DELETE FROM users');
      expect(await db.getAllUsers(), isEmpty);

      await db.createDefaultAdmin();

      final admin = await db.getUserByUsername('admin');
      expect(admin, isNotNull, reason: 'the default admin must be created');
      expect(admin!.role, 'admin');
      expect(await storedRoles(), {'admin'});
    });
  });
}
