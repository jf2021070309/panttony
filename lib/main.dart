import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/menu_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/client/menu_screen.dart';
import 'views/client/cart_screen.dart';
import 'views/client/checkout_screen.dart';
import 'views/client/order_status_screen.dart';
import 'views/admin/panel_screen.dart';
import 'views/admin/product_management_screen.dart';
import 'views/deliverer/orders_screen.dart';
import 'views/main_navigation.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('Iniciando Firebase...');
    await Firebase.initializeApp(); 
    print('Firebase inicializado correctamente.');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => MenuProvider()),
        ],
        child: const PanttonyApp(),
      ),
    );
  } catch (e) {
    print('ERROR CRÍTICO EN MAIN: $e');
  }
}

class PanttonyApp extends StatelessWidget {
  const PanttonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panttony Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/main': (context) => const MainNavigation(),
        '/menu': (context) => const MenuScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/status': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          return OrderStatusScreen(
            order: args is Map<String, dynamic> ? args : null,
            // Si pasas un String, lo manejaremos dentro de la pantalla
            orderId: args is String ? args : null, 
          );
        },
        '/admin': (context) => const AdminPanelScreen(),
        '/admin-products': (context) => const ProductManagementScreen(),
        '/deliverer': (context) => const DelivererOrdersScreen(),
      },
    );
  }
}
