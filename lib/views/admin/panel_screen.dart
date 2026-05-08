import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';

import '../../widgets/dashboard_header.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Stream<List<OrderModel>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _ordersStream = OrderService().getPendingOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DashboardHeader(
            title: 'Panel Admin',
            subtitle: 'Hoy es un gran día para Panttony',
            stats: [
              const StatItem(label: 'Pedidos', value: '12', icon: Icons.shopping_bag),
              const StatItem(label: 'Ventas', value: 'S/ 320', icon: Icons.payments),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.pushReplacementNamed(context, '/');
                },
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _ordersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final orders = snapshot.data ?? [];
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('¡Todo al día! No hay pedidos pendientes'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _OrderAdminCard(order: order);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/admin-products'),
        label: const Text('Gestionar Carta'),
        icon: const Icon(Icons.restaurant_menu),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _OrderAdminCard extends StatelessWidget {
  final OrderModel order;

  const _OrderAdminCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pedido #${order.id.substring(0, 5)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status.name.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                Text('S/ ${order.total.toStringAsFixed(2)}', 
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            ...order.items.map((item) => Text('${item.quantity}x ${item.productName}')),
            const SizedBox(height: 12),
            Text('Pago: ${order.paymentMethod.toUpperCase()}', 
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (order.status == OrderStatus.pendiente)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => OrderService().updateOrderStatus(order.id, OrderStatus.confirmado),
                      child: const Text('Confirmar'),
                    ),
                  ),
                if (order.status == OrderStatus.confirmado)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => OrderService().updateOrderStatus(order.id, OrderStatus.enPreparacion),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                      child: const Text('Preparar'),
                    ),
                  ),
                const SizedBox(width: 8),
                if (order.status != OrderStatus.asignado)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _assignDeliverer(context, order.id),
                      child: const Text('Asignar Repartidor'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _assignDeliverer(context, order.id),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Reasignar'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _assignDeliverer(BuildContext context, String orderId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Repartidor'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('usuarios')
                .where('role', isEqualTo: 'repartidor')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No hay repartidores registrados');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['nombre'] ?? 'Sin nombre';
                  final email = data['email'] ?? '';
                  
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name),
                    subtitle: Text(email),
                    onTap: () async {
                      await OrderService().assignDeliverer(orderId, docs[index].id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pedido asignado a $name')),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
