import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/config/router/app_router.dart';

/// `/workers` cases of the admin-only route guard (auth → Route Guard delta).
/// The generalized `routeGuardDecision` replaced `workersRedirectDecision`.
void main() {
  group('routeGuardDecision (guard de /workers)', () {
    test('admin puede navegar a /workers (sin redirect)', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'admin',
        currentPath: '/workers',
      );
      expect(decision, isNull);
    });

    test('super_admin ya no existe: queda redirigido a /', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'super_admin',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('cocina es redirigido a /', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'cocina',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('redes/vendedor es redirigido a /', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'redes',
        currentPath: '/workers',
      );
      expect(decision, '/');
      final vendedor = routeGuardDecision(
        authenticated: true,
        role: 'vendedor',
        currentPath: '/workers',
      );
      expect(vendedor, '/');
    });

    test('domicilio es redirigido a /', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'domicilio',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('mesero es redirigido a /', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'mesero',
        currentPath: '/workers',
      );
      expect(decision, '/');
    });

    test('sin sesión a /workers -> /login (nunca renderiza usuarios)', () async {
      final decision = routeGuardDecision(
        authenticated: false,
        role: '',
        currentPath: '/workers',
      );
      expect(decision, '/login');
    });

    test('no afecta rutas que no son /workers', () async {
      final decision = routeGuardDecision(
        authenticated: true,
        role: 'cocina',
        currentPath: '/orders/new',
      );
      expect(decision, isNull);
    });
  });
}
