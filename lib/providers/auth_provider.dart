import 'package:flutter/material.dart';

enum UserRole { cliente, empleado, repartidor }

class AuthProvider with ChangeNotifier {
  UserRole? _currentUserRole;
  String? _userId;

  UserRole? get currentUserRole => _currentUserRole;
  String? get userId => _userId;

  bool get isAuthenticated => _currentUserRole != null;

  Future<bool> login(String username, String password) async {
    // Simulating login logic with fixed credentials
    if (password == '123') {
      if (username == 'cliente') {
        _currentUserRole = UserRole.cliente;
        _userId = 'client_001';
        notifyListeners();
        return true;
      } else if (username == 'empleado') {
        _currentUserRole = UserRole.empleado;
        _userId = 'employee_001';
        notifyListeners();
        return true;
      } else if (username == 'repartidor') {
        _currentUserRole = UserRole.repartidor;
        _userId = 'repartidor_001';
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void logout() {
    _currentUserRole = null;
    _userId = null;
    notifyListeners();
  }
}
