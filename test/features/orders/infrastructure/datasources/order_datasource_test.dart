import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/orders/infrastructure/repositories/order_repository_impl.dart';

String _todayIso() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

RestaurantOrder _order({
  required String id,
  OrderState estado = OrderState.pedido,
  String? fechaPedido,
}) {
  return RestaurantOrder(
    id: id,
    clienteId: 'CLI-1',
    estado: estado,
    fechaPedido: fechaPedido,
    montoTotal: 150.0,
    creadoPorUsuarioId: 'u1',
  );
}

void main() {
  late AppDatabase db;
  late OrderDatasource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = OrderDatasource(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('createOrder — fechaPedido write', () {
    test('persists an explicit fechaPedido', () async {
      await ds.createOrder(_order(id: 'A1-0115-001', fechaPedido: '2026-01-15'));

      final row = await (db.select(db.restaurantOrders)
            ..where((o) => o.id.equals('A1-0115-001')))
          .getSingle();
      expect(row.fechaPedido, '2026-01-15');
    });

    test('defaults fechaPedido to today', () async {
      await ds.createOrder(_order(id: 'A1-0115-002'));

      final row = await (db.select(db.restaurantOrders)
            ..where((o) => o.id.equals('A1-0115-002')))
          .getSingle();
      expect(row.fechaPedido, _todayIso());
    });
  });

  group('updateOrderState — validated transitions', () {
    test('pedido → confirmado persists', () async {
      await ds.createOrder(_order(id: 'T-1'));

      await ds.updateOrderState('T-1', OrderState.confirmado);

      expect((await ds.getOrderById('T-1'))!.estado, OrderState.confirmado);
    });

    test('pedido → recogido throws StateError and leaves estado unchanged',
        () async {
      await ds.createOrder(_order(id: 'T-2'));

      await expectLater(
        ds.updateOrderState('T-2', OrderState.recogido),
        throwsA(isA<StateError>()),
      );
      expect((await ds.getOrderById('T-2'))!.estado, OrderState.pedido);
    });

    test('terminal recogido cannot transition at all', () async {
      await ds.createOrder(_order(id: 'T-3', estado: OrderState.recogido));

      await expectLater(
        ds.updateOrderState('T-3', OrderState.confirmado),
        throwsA(isA<StateError>()),
      );
      expect((await ds.getOrderById('T-3'))!.estado, OrderState.recogido);
    });

    test('no backwards transition confirmado → pedido', () async {
      await ds.createOrder(_order(id: 'T-4', estado: OrderState.confirmado));

      await expectLater(
        ds.updateOrderState('T-4', OrderState.pedido),
        throwsA(isA<StateError>()),
      );
      expect((await ds.getOrderById('T-4'))!.estado, OrderState.confirmado);
    });
  });

  group('unknown stored estado maps to pedido', () {
    test('raw legacy EN_COCINA row reads back as pedido', () async {
      await db.into(db.restaurantOrders).insert(
            RestaurantOrdersCompanion.insert(
              id: 'L-1',
              tipoPedido: '',
              clienteId: 'CLI-9',
              estado: 'EN_COCINA',
              creadoPorUsuarioId: 'u1',
              fechaPedido: const Value('2000-01-15'),
            ),
          );

      expect((await ds.getOrderById('L-1'))!.estado, OrderState.pedido);
      final all = await ds.getAllOrders();
      expect(
        all.firstWhere((o) => o.id == 'L-1').estado,
        OrderState.pedido,
      );
    });
  });

  group('updateOrder — day field', () {
    test('persists fechaPedido without touching fechaCreacion', () async {
      await ds.createOrder(_order(id: 'U-1', fechaPedido: '2000-01-15'));
      final before = (await ds.getOrderById('U-1'))!.fechaCreacion;

      await ds.updateOrder(_order(id: 'U-1', fechaPedido: '2000-02-01'));

      final updated = (await ds.getOrderById('U-1'))!;
      expect(updated.fechaPedido, '2000-02-01');
      expect(updated.fechaCreacion, before);
    });
  });

  group('day queries', () {
    test('getOrdersByDay returns only that business day', () async {
      await ds.createOrder(_order(id: 'D-1', fechaPedido: '2000-01-15'));
      await ds.createOrder(_order(id: 'D-2', fechaPedido: '2000-01-16'));
      await ds.createOrder(_order(id: 'D-3', fechaPedido: '2000-01-15'));

      final day = await ds.getOrdersByDay('2000-01-15');

      expect(day.map((o) => o.id).toSet(), {'D-1', 'D-3'});
    });

    test('getTodayOrders filters by fechaPedido, not fechaCreacion', () async {
      // Created now (today) but assigned to another business day.
      await ds.createOrder(_order(id: 'Q-1', fechaPedido: '2000-01-15'));
      // Created yesterday but assigned to today's business day.
      await db.into(db.restaurantOrders).insert(
            RestaurantOrdersCompanion.insert(
              id: 'Q-2',
              tipoPedido: '',
              clienteId: 'CLI-1',
              estado: 'pedido',
              creadoPorUsuarioId: 'u1',
              fechaPedido: Value(_todayIso()),
              fechaCreacion:
                  Value(DateTime.now().subtract(const Duration(days: 1))),
            ),
          );

      final today = await ds.getTodayOrders();
      final ids = today.map((o) => o.id).toSet();

      expect(ids, contains('Q-2'));
      expect(ids, isNot(contains('Q-1')));
    });
  });

  group('OrderRepositoryImpl day query delegation', () {
    test('getOrdersByDay delegates to the datasource', () async {
      final repo = OrderRepositoryImpl(ds);
      await ds.createOrder(_order(id: 'R-1', fechaPedido: '2000-03-01'));
      await ds.createOrder(_order(id: 'R-2', fechaPedido: '2000-03-02'));

      final day = await repo.getOrdersByDay('2000-03-01');

      expect(day.map((o) => o.id), ['R-1']);
    });
  });
}
