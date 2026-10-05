/// Estados del ciclo de vida de un pedido (máquina de tres estados).
///
/// Flujo único: **pedido → confirmado → recogido** (`recogido` es terminal).
/// No existe estado cancelado ni variante mesa/domicilio (spec:
/// Three-State Order Machine).
enum OrderState {
  pedido, // Pedido recién creado
  confirmado, // Confirmado (cocina/listo)
  recogido; // Recogido por el cliente (terminal)

  static const validTransitions = {
    pedido: {confirmado},
    confirmado: {recogido},
    recogido: <OrderState>{},
  };

  /// Returns `true` if this state can transition to [next].
  bool canTransitionTo(OrderState next) =>
      validTransitions[this]?.contains(next) ?? false;
}
