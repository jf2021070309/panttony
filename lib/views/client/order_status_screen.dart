import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../widgets/tracking_map.dart';

class OrderStatusScreen extends StatelessWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estado del Pedido')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final order = OrderModel.fromFirestore(data, orderId);

          return Column(
            children: [
              _buildStepper(order.status),
              const Spacer(),
              if (order.status == OrderStatus.en_camino)
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    child: TrackingMapWidget(
                      clienteDestino: LatLng(
                        order.customerLocation.latitude,
                        order.customerLocation.longitude,
                      ),
                      orderId: orderId,
                      isRepartidor: false,
                    ),
                  ),
                )
              else
                _buildStatusIllustration(order.status),
              const Spacer(),
              if (order.status == OrderStatus.entregado)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton(
                    onPressed: () => _showRatingDialog(context, orderId),
                    child: const Text('Confirmar Recepción y Calificar'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepper(OrderStatus currentStatus) {
    final statuses = OrderStatus.values;
    final currentIndex = statuses.indexOf(currentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(statuses.length, (index) {
            bool isCompleted = index <= currentIndex;
            bool isCurrent = index == currentIndex;
            
            return Row(
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: isCompleted ? AppColors.primary : Colors.grey[300],
                      child: isCompleted 
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statuses[index].displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 40,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: index < currentIndex ? AppColors.primary : Colors.grey[300],
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusIllustration(OrderStatus status) {
    IconData icon;
    String title;
    switch (status) {
      case OrderStatus.pendiente:
        icon = Icons.timer_outlined;
        title = 'Esperando confirmación...';
        break;
      case OrderStatus.confirmado:
        icon = Icons.check_circle_outline;
        title = '¡Pedido Confirmado!';
        break;
      case OrderStatus.en_preparacion:
        icon = Icons.restaurant_menu;
        title = 'Cocinando tus empanadas...';
        break;
      case OrderStatus.asignado:
        icon = Icons.person_pin_circle_outlined;
        title = 'Repartidor asignado';
        break;
      default:
        icon = Icons.celebration;
        title = '¡Entregado!';
    }

    return Column(
      children: [
        Icon(icon, size: 100, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showRatingDialog(BuildContext context, String orderId) {
    // Implement rating dialog logic here
  }
}
