import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

/// Datos del home calculados desde el modelo nuevo (`restaurant_orders`).
final homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final todayOrders = await repo.getTodayOrders();
  final monthOrders = await repo.getOrdersSince(monthStart);

  // El modelo de tres estados no modela método de pago: el desglose
  // EF/TR queda en 0 (se elimina junto con la pantalla en fase 4).
  double salesToday = 0;
  for (final o in todayOrders) {
    salesToday += o.montoTotal;
  }

  double salesMonth = 0;
  for (final o in monthOrders) {
    salesMonth += o.montoTotal;
  }

  return {
    'todayOrders': todayOrders,
    'todayCount': todayOrders.length,
    'pendingCount': todayOrders
        .where((o) => o.estado == OrderState.pedido)
        .length,
    'salesToday': salesToday,
    'cashToday': 0.0,
    'transferToday': 0.0,
    'salesMonth': salesMonth,
    'cashMonth': 0.0,
    'transferMonth': 0.0,
    'monthCount': monthOrders.length,
  };
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _userName = 'Usuario';
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(homeDataProvider);
    });
  }

  Future<void> _loadUserName() async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id');
    final role = await storage.read(key: 'user_role') ?? '';
    if (mounted) {
      setState(() => _userRole = role);
    }
    if (userId != null) {
      final db = AppDatabase.instance;
      final users = await db.getAllUsers();
      final currentUser = users.where((u) => u.id == userId).firstOrNull;
      if (mounted && currentUser != null) {
        setState(() {
          _userName = currentUser.fullName;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 18) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  // ── Role helpers (2-role model) ───────────────────────────────────
  bool get _isAdmin => _userRole == 'admin';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AppColors.darkTextPrimary : Colors.white;
    final themeColors = AppColors.forBrightness(Theme.of(context).brightness);

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeDataProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.accent,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  '${_getGreeting()},',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accent,
                        AppColors.accent.withValues(alpha: 0.8),
                        themeColors.warning.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, child) {
                  final homeData = ref.watch(homeDataProvider);

                  return homeData.when(
                    data: (data) => _buildContent(data),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(50),
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error al cargar datos',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(homeDataProvider),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    // ── Two dashboards (role-flows): admin / vendedor ───────────
    // Rol desconocido → dashboard de vendedor (menor privilegio).
    if (_isAdmin) return _buildAdminDashboard(data);
    return _buildVendedorDashboard(data);
  }

  // ─────────────────────────────────────────────────────────────
  // VENDEDOR Dashboard
  // ─────────────────────────────────────────────────────────────

  Widget _buildVendedorDashboard(Map<String, dynamic> data) {
    final todayOrders = _getTodayOrdersCount(data);
    final pendingConfirm = _getPendingConfirmationCount(data);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRoleCard(
            icon: Icons.point_of_sale,
            title: 'Vendedor',
            subtitle: 'Atención al cliente',
          ),
          const SizedBox(height: 20),

          // Shortcuts
          _buildActionButton(
            icon: Icons.add_circle_outline,
            label: 'Nuevo Pedido',
            color: AppColors.accent,
            onTap: () => context.go('/orders/new'),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            icon: Icons.history,
            label: 'Historial de Pedidos',
            color: AppColors.accent,
            onTap: () => context.go('/orders/history'),
          ),
          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              _buildStatCard(
                'Pedidos Hoy',
                '${todayOrders}',
                Icons.receipt_long,
                AppColors.accent,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Pendientes',
                '${pendingConfirm}',
                Icons.schedule,
                AppColors.warningLight,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Access links
          Text(
            'ACCESOS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickLink('Clientes', Icons.people, () => context.go('/clients')),
          _buildQuickLink('Días', Icons.calendar_month, () => context.go('/days')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ADMIN Dashboard (existing layout + daily close shortcut)
  // ─────────────────────────────────────────────────────────────

  Widget _buildAdminDashboard(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nuevo Pedido shortcut (admin)
          _buildActionButton(
            icon: Icons.add_circle_outline,
            label: 'Nuevo Pedido',
            color: AppColors.accent,
            onTap: () => context.go('/orders/new'),
          ),
          const SizedBox(height: 12),

          // Daily Close shortcut
          _buildActionButton(
            icon: Icons.account_balance,
            label: 'Cierre del Día',
            color: AppColors.accent,
            onTap: () => context.go('/daily-close'),
          ),
          const SizedBox(height: 24),

          // ====== HOY ======
          _buildSectionTitle('HOY'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Ventas', '\$${data['salesToday']}', Icons.attach_money, Colors.green),
              const SizedBox(width: 12),
              _buildStatCard('Efectivo', '\$${data['cashToday']}', Icons.payments, Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Transfer', '\$${data['transferToday']}', Icons.account_balance_wallet, Colors.purple),
              const SizedBox(width: 12),
              _buildStatCard('Pedidos', '${data['todayCount']}', Icons.receipt_long, AppColors.accent),
            ],
          ),

          const SizedBox(height: 24),

          // ====== MES ======
          _buildSectionTitle('MES ACTUAL'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Ventas', '\$${data['salesMonth']}', Icons.attach_money, AppColors.accent),
              const SizedBox(width: 12),
              _buildStatCard('Efectivo', '\$${data['cashMonth']}', Icons.payments, Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Transfer', '\$${data['transferMonth']}', Icons.account_balance_wallet, Colors.purple),
              const SizedBox(width: 12),
              _buildStatCard('Pedidos', '${data['monthCount']}', Icons.receipt_long, AppColors.accent),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Access Buttons
          _buildQuickAccessButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent,
            AppColors.accent.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.bungee(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLink(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  int _getTodayOrdersCount(Map<String, dynamic> data) =>
      (data['todayCount'] as int?) ?? 0;

  int _getPendingConfirmationCount(Map<String, dynamic> data) =>
      (data['pendingCount'] as int?) ?? 0;

  Widget _buildQuickAccessButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCESO RÁPIDO',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickButton(
                'Clientes',
                Icons.people_outline,
                const Color(0xFF378ADD),
                () => context.go('/clients'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickButton(
                'Productos',
                Icons.inventory_2_outlined,
                const Color(0xFF1D9E75),
                () => context.go('/products'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickButton(
                'Cierre Día',
                Icons.account_balance,
                const Color(0xFFEF9F27),
                () => context.go('/daily-close'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
