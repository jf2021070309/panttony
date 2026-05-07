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
import 'views/deliverer/orders_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Descomentar después de añadir google-services.json

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
      ],
      child: const PanttonyApp(),
    ),
  );
}

class PanttonyApp extends StatelessWidget {
  const PanttonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panttony Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/menu': (context) => const MenuScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/status': (context) => OrderStatusScreen(
          orderId: ModalRoute.of(context)!.settings.arguments as String,
        ),
        '/admin': (context) => const AdminPanelScreen(),
        '/deliverer': (context) => const DelivererOrdersScreen(),
      },
    );
  }
}
