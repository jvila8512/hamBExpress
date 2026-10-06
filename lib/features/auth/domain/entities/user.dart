

/// The allowed role set after the v16 remap: exactly two values exist.
/// Legacy stored roles are normalized to these by
/// `mapLegacyRoleToAppRole` (Dart side) and by the v16 migration CASE
/// (database side).
enum UserRole { admin, vendedor }

class User {

  final String id;
  final String email;
  final String fullName;
  final List<String> roles;
  final String token;
  final String phone;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    required this.token,
    this.phone = '',
  });

  bool get isAdmin {
    return roles.contains(UserRole.admin.name);
  }

  bool get isVendedor {
    return roles.contains(UserRole.vendedor.name);
  }

}
