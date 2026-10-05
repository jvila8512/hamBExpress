import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/order_id.dart';

void main() {
  group('buildOrderId', () {
    test('admin role uses A prefix with default originSeq 1', () {
      expect(
        buildOrderId(role: 'admin', mmdd: '1003', dailySeq: 7),
        'A1-1003-007',
      );
    });

    test('vendedor role uses V prefix with default originSeq 1', () {
      expect(
        buildOrderId(role: 'vendedor', mmdd: '1003', dailySeq: 7),
        'V1-1003-007',
      );
    });

    test('explicit originSeq is embedded after the role prefix', () {
      expect(
        buildOrderId(role: 'admin', originSeq: 2, mmdd: '1003', dailySeq: 7),
        'A2-1003-007',
      );
      expect(
        buildOrderId(
            role: 'vendedor', originSeq: 3, mmdd: '1231', dailySeq: 1),
        'V3-1231-001',
      );
    });

    test('dailySeq is zero-padded to 3 digits', () {
      expect(
        buildOrderId(role: 'admin', mmdd: '1003', dailySeq: 1),
        'A1-1003-001',
      );
      expect(
        buildOrderId(role: 'admin', mmdd: '1003', dailySeq: 42),
        'A1-1003-042',
      );
      expect(
        buildOrderId(role: 'admin', mmdd: '1003', dailySeq: 123),
        'A1-1003-123',
      );
    });

    test('mmdd is passed through verbatim', () {
      expect(
        buildOrderId(role: 'admin', mmdd: '1231', dailySeq: 7),
        'A1-1231-007',
      );
    });

    test('unknown role throws ArgumentError', () {
      expect(
        () => buildOrderId(role: 'cocina', mmdd: '1003', dailySeq: 7),
        throwsArgumentError,
      );
      expect(
        () => buildOrderId(role: 'Admin', mmdd: '1003', dailySeq: 7),
        throwsArgumentError,
      );
      expect(
        () => buildOrderId(role: '', mmdd: '1003', dailySeq: 7),
        throwsArgumentError,
      );
    });
  });
}
