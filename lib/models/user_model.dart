enum UserRole { cliente, admin, repartidor }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password; // Añadido campo password
  final UserRole role;
  final String? fcmToken; // Para notificaciones push

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      password: data['password'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'cliente'),
        orElse: () => UserRole.cliente,
      ),
      fcmToken: data['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role.name,
      'fcmToken': fcmToken,
    };
  }
}
