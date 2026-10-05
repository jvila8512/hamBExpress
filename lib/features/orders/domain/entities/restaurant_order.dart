import 'order_state.dart';

/// An item within a restaurant order.
class OrderItem {
  final String code;
  final int qty;
  final double price;

  const OrderItem({
    required this.code,
    required this.qty,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      code: json['code']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'qty': qty,
    'price': price,
  };

  double get subtotal => qty * price;
}

/// Represents a restaurant order in the day-based ordering model.
///
/// Single flow: **pedido → confirmado → recogido** (three-state machine).
/// The business day [fechaPedido] (ISO calendar date) is separate from the
/// creation timestamp [fechaCreacion] (spec: Order Day Field).
class RestaurantOrder {
  final String id;
  final String clienteId;
  final OrderState estado;
  final double montoTotal;
  final String creadoPorUsuarioId;

  /// Business day (`yyyy-MM-dd`), defaults to today.
  final String fechaPedido;
  final DateTime? fechaCreacion;
  final List<OrderItem> items;

  RestaurantOrder({
    required this.id,
    required this.clienteId,
    this.estado = OrderState.pedido,
    this.montoTotal = 0.0,
    required this.creadoPorUsuarioId,
    String? fechaPedido,
    this.fechaCreacion,
    this.items = const [],
  }) : fechaPedido = fechaPedido ?? _todayIso();

  /// Create from a JSON map (deserialized from API or storage).
  ///
  /// An unknown or legacy `estado` (e.g. `EN_COCINA`) maps to
  /// [OrderState.pedido] (spec: Unknown or legacy state maps to pedido).
  factory RestaurantOrder.fromJson(Map<String, dynamic> json) {
    return RestaurantOrder(
      id: json['id']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      estado: _parseState(json['estado']?.toString()),
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0.0,
      creadoPorUsuarioId: json['creado_por_usuario_id']?.toString() ?? '',
      fechaPedido: json['fecha_pedido']?.toString(),
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'].toString())
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'cliente_id': clienteId,
    'estado': estado.name,
    'monto_total': montoTotal,
    'creado_por_usuario_id': creadoPorUsuarioId,
    'fecha_pedido': fechaPedido,
    if (fechaCreacion != null)
      'fecha_creacion': fechaCreacion!.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  /// Create a copy with updated fields.
  RestaurantOrder copyWith({
    String? id,
    String? clienteId,
    OrderState? estado,
    double? montoTotal,
    String? creadoPorUsuarioId,
    String? fechaPedido,
    DateTime? fechaCreacion,
    List<OrderItem>? items,
  }) {
    return RestaurantOrder(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      estado: estado ?? this.estado,
      montoTotal: montoTotal ?? this.montoTotal,
      creadoPorUsuarioId: creadoPorUsuarioId ?? this.creadoPorUsuarioId,
      fechaPedido: fechaPedido ?? this.fechaPedido,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      items: items ?? this.items,
    );
  }

  static String _todayIso() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  static OrderState _parseState(String? state) {
    if (state == null) return OrderState.pedido;
    return OrderState.values.firstWhere(
      (s) => s.name == state,
      orElse: () => OrderState.pedido,
    );
  }
}
