import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: OrderService().getPendingOrders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final orders = snapshot.data!;
          if (orders.isEmpty) return const Center(child: Text('No hay pedidos pendientes'));

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
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => OrderService().updateOrderStatus(order.id, OrderStatus.confirmado),
                    child: const Text('Confirmar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _assignDeliverer(context, order.id),
                    child: const Text('Asignar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _assignDeliverer(BuildContext context, String orderId) {
    // Mocking deliverer assignment for now
    OrderService().assignDeliverer(orderId, 'repartidor123');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Repartidor asignado con éxito')),
    );
  }
}
