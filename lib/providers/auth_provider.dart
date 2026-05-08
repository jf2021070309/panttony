import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  UserRole? _currentUserRole;
  String? _userId;
  String? _userName;

  UserRole? get currentUserRole => _currentUserRole;
  String? get userId => _userId;
  String? get userName => _userName;

  bool get isAuthenticated => _userId != null;

  Future<bool> login(String email, String password) async {
    try {
      print('Intentando login para: $email');
      // Añadimos un timeout de 10 segundos para evitar ANR si no hay conexión
      final querySnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final userId = querySnapshot.docs.first.id;
        
        final user = UserModel.fromMap(userData, userId);
        
        _currentUserRole = user.role;
        _userId = user.id;
        _userName = user.name;
        
        print('Login exitoso: ${user.name} - Rol: ${user.role}');
        notifyListeners();
        return true;
      } else {
        print('Usuario no encontrado o contraseña incorrecta');
      }
    } catch (e) {
      print('Error en login o timeout: $e');
    }
    return false;
  }

  void logout() {
    _currentUserRole = null;
    _userId = null;
    _userName = null;
    notifyListeners();
  }
}
