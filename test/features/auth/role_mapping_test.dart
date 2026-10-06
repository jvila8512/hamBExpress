import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/auth/domain/entities/user.dart';
import 'package:etecsa/features/auth/infrastructure/datasources/auth_datasource_impl.dart';

/// The Dart-side role remap must agree EXACTLY with the v16 migration CASE in
/// `lib/core/database/app_database.dart` (`_remapRolesToTwoRoles`):
///
/// ```sql
/// UPDATE users SET role = CASE role
///   WHEN 'super_admin' THEN 'admin'
///   WHEN 'admin'       THEN 'admin'
///   WHEN 'redes'       THEN 'vendedor'
///   WHEN 'cocina'      THEN 'vendedor'
///   WHEN 'mesero'      THEN 'vendedor'
///   WHEN 'domicilio'   THEN 'vendedor'
///   WHEN 'almacenero'  THEN 'vendedor'
///   WHEN 'vendedor'    THEN 'vendedor'
///   ELSE 'vendedor' END
/// ```
void main() {
  group('mapLegacyRoleToAppRole — 8 legacy DB values → 2 roles', () {
    test('super_admin maps to admin', () {
      expect(mapLegacyRoleToAppRole('super_admin'), 'admin');
    });

    test('admin maps to admin', () {
      expect(mapLegacyRoleToAppRole('admin'), 'admin');
    });

    test('redes maps to vendedor', () {
      expect(mapLegacyRoleToAppRole('redes'), 'vendedor');
    });

    test('cocina maps to vendedor', () {
      expect(mapLegacyRoleToAppRole('cocina'), 'vendedor');
    });

    test('mesero maps to vendedor', () {
      expect(mapLegacyRoleToAppRole('mesero'), 'vendedor');
    });

    test('domicilio maps to vendedor', () {
      expect(mapLegacyRoleToAppRole('domicilio'), 'vendedor');
    });

    test('almacenero maps to vendedor', () {
      expect(mapLegacyRoleToAppRole('almacenero'), 'vendedor');
    });

    test('vendedor maps to vendedor', () {
      expect(mapLegacyRoleToAppRole('vendedor'), 'vendedor');
    });

    test('unknown value maps to vendedor like the SQL ELSE branch', () {
      expect(mapLegacyRoleToAppRole('nobody'), 'vendedor');
      expect(mapLegacyRoleToAppRole(''), 'vendedor');
    });

    test('every legacy value lands in the two-role set', () {
      const legacy = [
        'super_admin',
        'admin',
        'redes',
        'cocina',
        'mesero',
        'domicilio',
        'almacenero',
        'vendedor',
      ];
      for (final value in legacy) {
        expect(
          mapLegacyRoleToAppRole(value),
          anyOf('admin', 'vendedor'),
          reason: '"$value" must not survive outside {admin, vendedor}',
        );
      }
    });
  });

  group('UserRole enum — allowed role set', () {
    test('contains exactly admin and vendedor', () {
      expect(UserRole.values, [UserRole.admin, UserRole.vendedor]);
    });

    test('enum names match the stored role strings', () {
      expect(UserRole.admin.name, 'admin');
      expect(UserRole.vendedor.name, 'vendedor');
    });
  });

  group('User two-role getters', () {
    test('isAdmin true only for the admin role', () {
      final admin = User(
        id: '1',
        email: 'admin@test.com',
        fullName: 'Admin User',
        roles: ['admin'],
        token: 'abc123',
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isVendedor, isFalse);
    });

    test('isVendedor true only for the vendedor role', () {
      final vendedor = User(
        id: '2',
        email: 'vendedor@test.com',
        fullName: 'Vendedor User',
        roles: ['vendedor'],
        token: 'abc123',
      );
      expect(vendedor.isVendedor, isTrue);
      expect(vendedor.isAdmin, isFalse);
    });

    test('legacy role strings are not recognized as any role', () {
      final legacy = User(
        id: '3',
        email: 'legacy@test.com',
        fullName: 'Legacy User',
        roles: ['cocina'],
        token: 'abc123',
      );
      expect(legacy.isAdmin, isFalse);
      expect(legacy.isVendedor, isFalse);
    });

    test('empty roles list returns false for both', () {
      final none = User(
        id: '4',
        email: 'none@test.com',
        fullName: 'No Roles',
        roles: [],
        token: 'abc123',
      );
      expect(none.isAdmin, isFalse);
      expect(none.isVendedor, isFalse);
    });
  });

  group('User phone field', () {
    test('phone defaults to empty string', () {
      final user = User(
        id: '1',
        email: 'test@test.com',
        fullName: 'Test User',
        roles: ['vendedor'],
        token: 'abc123',
      );
      expect(user.phone, '');
    });

    test('phone can be set via constructor', () {
      final user = User(
        id: '2',
        email: 'test@test.com',
        fullName: 'Test User',
        roles: ['vendedor'],
        token: 'abc123',
        phone: '53512345',
      );
      expect(user.phone, '53512345');
    });

    test('phone is independent of other fields', () {
      final user = User(
        id: '3',
        email: 'a@b.com',
        fullName: 'User',
        roles: ['admin'],
        token: 'xyz',
        phone: '53567890',
      );
      expect(user.phone, '53567890');
      expect(user.id, '3');
      expect(user.roles, ['admin']);
    });
  });
}
