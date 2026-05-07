import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    bool success = await auth.login(
      _usernameController.text.trim().toLowerCase(),
      _passwordController.text.trim()
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        switch (auth.currentUserRole) {
          case UserRole.cliente:
            Navigator.pushReplacementNamed(context, '/menu');
            break;
          case UserRole.empleado:
            Navigator.pushReplacementNamed(context, '/admin');
            break;
          case UserRole.repartidor:
            Navigator.pushReplacementNamed(context, '/deliverer');
            break;
          default:
            break;
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas (Usa: cliente/123, empleado/123, etc.)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bienvenido',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  const Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _initializeData,
                      child: const Text('¿Primera vez? Inicializar Base de Datos', 
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Insertar Productos
      final products = [
        {'id': 'q1', 'name': 'Tres Quesos', 'price': 4.0, 'category': 'queso', 'description': 'Empanada de tres quesos'},
        {'id': 'c1', 'name': 'Rocoto Relleno', 'price': 7.5, 'category': 'criolla', 'description': 'Sabor arequipeño'},
      ];

      for (var p in products) {
        await firestore.collection('productos').doc(p['id'] as String).set(p);
      }

      // Insertar Usuarios de prueba
      await firestore.collection('usuarios').doc('client_001').set({
        'nombre': 'Cliente Prueba',
        'rol': 'cliente',
        'id': 'client_001'
      });
      await firestore.collection('usuarios').doc('employee_001').set({
        'nombre': 'Admin Panttony',
        'rol': 'empleado',
        'id': 'employee_001'
      });
      await firestore.collection('usuarios').doc('repartidor_001').set({
        'nombre': 'Juan Motos',
        'rol': 'repartidor',
        'id': 'repartidor_001'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base de datos inicializada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 100, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Panttony App',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
