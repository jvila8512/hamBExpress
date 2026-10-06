import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:etecsa/features/auth/presentation/screens/login_screen.dart';
import 'package:etecsa/features/auth/presentation/screens/register_screen.dart';
import 'package:etecsa/features/shared/presentation/screens/splash_screen.dart';
import 'package:etecsa/features/products/presentation/screens/products_screen.dart';
import 'package:etecsa/features/products/presentation/screens/product_form_screen.dart';
import 'package:etecsa/features/home/presentation/screens/home_screen.dart';
import 'package:etecsa/features/settings/presentation/screens/settings_screen.dart';
import 'package:etecsa/features/orders/presentation/screens/order_form_screen.dart';
import 'package:etecsa/features/orders/presentation/screens/order_history_screen.dart';
import 'package:etecsa/features/clients/presentation/screens/client_management_screen.dart';
import 'package:etecsa/features/daily_close/presentation/screens/daily_close_screen.dart';
import 'package:etecsa/features/workers/presentation/screens/workers_screen.dart';
import 'package:etecsa/core/database/app_database.dart';

const _secureStorage = FlutterSecureStorage();

Future<bool> _isLoggedIn() async {
  final token = await _secureStorage.read(key: 'session_token');
  return token != null && token.isNotEmpty;
}

/// Guard de ruta `/workers` (navegación directa): puro y testeable.
/// Devuelve el redirect a aplicar o null si se permite navegar.
///
/// Solo `admin` y `super_admin` pueden entrar; los demás roles van a su home
/// (`/`); sin sesión a login (el login decide registro si no hay usuarios).
String? workersRedirectDecision({
  required bool loggedIn,
  required String role,
  required String currentPath,
}) {
  if (currentPath != '/workers') return null;
  if (!loggedIn) return '/login';
  final isAdminOrSuper = role == 'admin' || role == 'super_admin';
  return isAdminOrSuper ? null : '/';
}

Future<bool> _isFirstTime() async {
  try {
    final db = AppDatabase.instance;
    final users = await db.getAllUsers();
    // Buscar si ya existe el admin
    final hasAdmin = users.any((u) => u.username.toLowerCase() == 'admin');
    return !hasAdmin; // Si no hay admin, ir a registro
  } catch (e) {
    return true;
  }
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // ── Home ─────────────────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),

    // ── Products ─────────────────────────────────────────────────
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/products/new',
      builder: (context, state) => const ProductFormScreen(),
    ),
    GoRoute(
      path: '/products/edit/:id',
      builder: (context, state) {
        final productId = state.pathParameters['id'];
        return ProductFormScreen(productId: productId);
      },
    ),

    // ── Orders ───────────────────────────────────────────────────
    GoRoute(
      path: '/orders/new',
      builder: (context, state) => const OrderFormScreen(),
    ),
    GoRoute(
      path: '/orders/history',
      builder: (context, state) => const OrderHistoryScreen(),
    ),

    // ── Workers (admin/super_admin) ─────────────────────────────
    GoRoute(
      path: '/workers',
      builder: (context, state) => const WorkersScreen(),
    ),

    // ── Clients ──────────────────────────────────────────────────
    GoRoute(
      path: '/clients',
      builder: (context, state) => const ClientManagementScreen(),
    ),

    // ── Daily Close ──────────────────────────────────────────────
    GoRoute(
      path: '/daily-close',
      builder: (context, state) => const DailyCloseScreen(),
    ),

    // ── Settings ─────────────────────────────────────────────────
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],

  redirect: (BuildContext context, GoRouterState state) async {
    final currentPath = state.uri.path;

    // Rutas públicas que no requieren auth
    if (currentPath == '/splash' ||
        currentPath == '/login' ||
        currentPath == '/register') {
      return null;
    }

    final isLoggingIn = currentPath == '/login';
    final isRegistering = currentPath == '/register';
    final isFirst = await _isFirstTime();
    final loggedIn = await _isLoggedIn();

    // Verificar acceso a /workers (solo admin y super_admin)
    final role = await _secureStorage.read(key: 'user_role') ?? '';
    final workersRedirect = workersRedirectDecision(
      loggedIn: loggedIn,
      role: role,
      currentPath: currentPath,
    );
    if (workersRedirect != null) {
      return workersRedirect;
    }

    // Primera vez sin usuarios -> Register
    if (isFirst && !isRegistering) {
      return '/register';
    }

    // Si ya hay usuarios y va a register -> Login
    if (!isFirst && isRegistering) {
      return '/login';
    }

    // Si ya está logueado y va a login/register -> Home
    if (loggedIn && (isLoggingIn || isRegistering)) {
      return '/';
    }

    // Si no está logueado e intenta entrar -> Login
    if (currentPath == '/' && !loggedIn) {
      return isFirst ? '/register' : '/login';
    }

    return null;
  },
);
