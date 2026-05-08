import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../core/theme.dart';
import 'client/menu_screen.dart';
import 'client/my_orders_screen.dart';
import 'admin/panel_screen.dart';
import 'admin/product_management_screen.dart';
import 'deliverer/orders_screen.dart';
import 'deliverer/deliverer_map_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  List<Widget> _getClientScreens() => [
    const MenuScreen(),
    const MyOrdersScreen(),
    const ProfileScreen(),
  ];

  List<Widget> _getAdminScreens() => [
    const AdminPanelScreen(),
    const ProductManagementScreen(),
    const ProfileScreen(),
  ];

  List<Widget> _getDelivererScreens() => [
    const DelivererOrdersScreen(),
    const DelivererMapScreen(),
    const ProfileScreen(),
  ];

  List<BottomNavigationBarItem> _getClientItems() => [
    const BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Carta'),
    const BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Mis Pedidos'),
    const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
  ];

  List<BottomNavigationBarItem> _getAdminItems() => [
    const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Pedidos'),
    const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Carta'),
    const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Ventas'),
  ];

  List<BottomNavigationBarItem> _getDelivererItems() => [
    const BottomNavigationBarItem(icon: Icon(Icons.motorcycle), label: 'Entregas'),
    const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Ruta'),
    const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mi Perfil'),
  ];

  UserRole? _lastRole;
  List<Widget> _screens = [];
  List<BottomNavigationBarItem> _items = [];

  void _updateNavigation(UserRole role) {
    if (_lastRole == role) return;
    _lastRole = role;
    
    switch (role) {
      case UserRole.admin:
        _screens = _getAdminScreens();
        _items = _getAdminItems();
        break;
      case UserRole.repartidor:
        _screens = _getDelivererScreens();
        _items = _getDelivererItems();
        break;
      default:
        _screens = _getClientScreens();
        _items = _getClientItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final role = auth.currentUserRole ?? UserRole.cliente;
    
    _updateNavigation(role);

    return Scaffold(
      body: _screens[_selectedIndex >= _screens.length ? 0 : _selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex >= _items.length ? 0 : _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          items: _items,
        ),
      ),
    );
  }
}
