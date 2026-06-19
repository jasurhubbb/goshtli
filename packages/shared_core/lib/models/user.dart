/// Canonical User model shared between buyer + partner apps. Mirrors backend apps/accounts/User.
///
/// v3.8 adds QASSOB to UserRole. The partner app reads `role` to branch its tab layout (SUPPLIER sees
/// Buyurtmalar/Katalog, QASSOB sees Ishlar/Jadval).
enum UserRole {
  admin,
  supplier,
  buyer,
  qassob,
}

UserRole _roleFromString(String s) {
  switch (s) {
    case 'ADMIN':    return UserRole.admin;
    case 'SUPPLIER': return UserRole.supplier;
    case 'BUYER':    return UserRole.buyer;
    case 'QASSOB':   return UserRole.qassob;
  }
  return UserRole.buyer;                                   // permissive default keeps legacy responses parsing
}

String roleToWire(UserRole r) {
  switch (r) {
    case UserRole.admin: return 'ADMIN';
    case UserRole.supplier: return 'SUPPLIER';
    case UserRole.buyer: return 'BUYER';
    case UserRole.qassob: return 'QASSOB';
  }
}


class User {
  final int id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final bool isActive;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['id'] ?? 0) as int,
    email: (json['email'] ?? '') as String,
    fullName: (json['full_name'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    role: _roleFromString((json['role'] ?? 'BUYER') as String),
    isActive: (json['is_active'] ?? true) as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'role': roleToWire(role),
    'is_active': isActive,
  };

  bool get isBuyer => role == UserRole.buyer;
  bool get isSupplier => role == UserRole.supplier;
  bool get isQassob => role == UserRole.qassob;
  bool get isAdmin => role == UserRole.admin;
  /// True for any partner-app role.
  bool get isPartner => role == UserRole.supplier || role == UserRole.qassob;
}
