import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/config/router/app_router.dart';

/// Decision table for the Admin-Only Route Guard (auth delta) and the
/// design decision "one fn": admin-only `/workers`, `/settings`;
/// authenticated-any-role `/products*`; `/orders`, `/clients`, `/days`
/// open to both roles.
void main() {
  group('routeGuardDecision — admin-only paths allow admin', () {
    test('admin reaches /workers', () {
      expect(
        routeGuardDecision(
          currentPath: '/workers',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('admin reaches /settings', () {
      expect(
        routeGuardDecision(
          currentPath: '/settings',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });
  });

  group('routeGuardDecision — vendedor is redirected off admin paths', () {
    test('vendedor is redirected from /workers to /', () {
      expect(
        routeGuardDecision(
          currentPath: '/workers',
          role: 'vendedor',
          authenticated: true,
        ),
        '/',
      );
    });

    test('vendedor is redirected from /settings to /', () {
      expect(
        routeGuardDecision(
          currentPath: '/settings',
          role: 'vendedor',
          authenticated: true,
        ),
        '/',
      );
    });

    test('legacy super_admin no longer bypasses the guard', () {
      expect(
        routeGuardDecision(
          currentPath: '/workers',
          role: 'super_admin',
          authenticated: true,
        ),
        '/',
      );
    });
  });

  group('routeGuardDecision — unauthenticated deep links go to login', () {
    test('anonymous /workers redirects to /login', () {
      expect(
        routeGuardDecision(
          currentPath: '/workers',
          role: '',
          authenticated: false,
        ),
        '/login',
      );
    });

    test('anonymous /settings redirects to /login', () {
      expect(
        routeGuardDecision(
          currentPath: '/settings',
          role: '',
          authenticated: false,
        ),
        '/login',
      );
    });

    test('anonymous /products redirects to /login', () {
      expect(
        routeGuardDecision(
          currentPath: '/products',
          role: '',
          authenticated: false,
        ),
        '/login',
      );
    });
  });

  group('routeGuardDecision — shared paths stay open to both roles', () {
    test('vendedor reaches /orders/history', () {
      expect(
        routeGuardDecision(
          currentPath: '/orders/history',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('vendedor reaches /orders/new', () {
      expect(
        routeGuardDecision(
          currentPath: '/orders/new',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('admin reaches /orders/history', () {
      expect(
        routeGuardDecision(
          currentPath: '/orders/history',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('vendedor reaches /clients', () {
      expect(
        routeGuardDecision(
          currentPath: '/clients',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('vendedor reaches /days', () {
      expect(
        routeGuardDecision(
          currentPath: '/days',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('admin reaches /days', () {
      expect(
        routeGuardDecision(
          currentPath: '/days',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });

    // ── Productos: abierto a ambos roles (menú único MVP) ──
    test('admin reaches /products', () {
      expect(
        routeGuardDecision(
          currentPath: '/products',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('admin reaches /products/new', () {
      expect(
        routeGuardDecision(
          currentPath: '/products/new',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('admin reaches /products/edit/:id', () {
      expect(
        routeGuardDecision(
          currentPath: '/products/edit/abc-123',
          role: 'admin',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('vendedor reaches /products', () {
      expect(
        routeGuardDecision(
          currentPath: '/products',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('vendedor reaches /products/new', () {
      expect(
        routeGuardDecision(
          currentPath: '/products/new',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });

    test('vendedor reaches /products/edit/:id', () {
      expect(
        routeGuardDecision(
          currentPath: '/products/edit/abc-123',
          role: 'vendedor',
          authenticated: true,
        ),
        isNull,
      );
    });
  });

  group('routeGuardDecision — public paths are never guarded', () {
    test('anonymous /login is left alone', () {
      expect(
        routeGuardDecision(
          currentPath: '/login',
          role: '',
          authenticated: false,
        ),
        isNull,
      );
    });

    test('anonymous /register is left alone', () {
      expect(
        routeGuardDecision(
          currentPath: '/register',
          role: '',
          authenticated: false,
        ),
        isNull,
      );
    });

    test('anonymous /splash is left alone', () {
      expect(
        routeGuardDecision(
          currentPath: '/splash',
          role: '',
          authenticated: false,
        ),
        isNull,
      );
    });
  });
}
