/// Builds the unique per-device order ID in the format
/// `{origen}{seq}-{MMDD}-{seq}`, e.g. `A1-1003-007`.
///
/// - Role `admin` → prefix `A`; `vendedor` → prefix `V`.
/// - [originSeq] is the device ordinal (defaults to 1).
/// - [mmdd] is the creation month/day (`MMDD`), passed through verbatim.
/// - [dailySeq] is the daily sequence, zero-padded to 3 digits.
///
/// Throws an [ArgumentError] when [role] is outside `{admin, vendedor}`.
String buildOrderId({
  required String role,
  int originSeq = 1,
  required String mmdd,
  required int dailySeq,
}) {
  final prefix = switch (role) {
    'admin' => 'A',
    'vendedor' => 'V',
    _ => throw ArgumentError.value(
        role,
        'role',
        'Only admin and vendedor roles exist',
      ),
  };
  return '$prefix$originSeq-$mmdd-${dailySeq.toString().padLeft(3, '0')}';
}
