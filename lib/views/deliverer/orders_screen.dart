import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/websocket_manager.dart';
import '../../services/location_service.dart';

import '../../widgets/dashboard_header.dart';

class DelivererOrdersScreen extends StatelessWidget {
  const DelivererOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          DashboardHeader(
            title: '¡Hola, Repartidor!',
            subtitle: 'Listo para repartir felicidad',
            stats: [
              const StatItem(label: 'Rutas', value: '3', icon: Icons.map),
              const StatItem(label: 'Propinas', value: 'S/ 45', icon: Icons.stars),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos')
                  .where('delivererId', isEqualTo: authProvider.userId)
                  // .where('status', isEqualTo: 'asignado') // Comentado para ver todos los estados por ahora
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delivery_dining_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No tienes entregas asignadas en este momento', 
                          style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final order = OrderModel.fromFirestore(
                      docs[index].data() as Map<String, dynamic>, 
                      docs[index].id
                    );
                    return _DelivererOrderCard(order: order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DelivererOrderCard extends StatefulWidget {
  final OrderModel order;

  const _DelivererOrderCard({required this.order});

  @override
  State<_DelivererOrderCard> createState() => _DelivererOrderCardState();
}

class _DelivererOrderCardState extends State<_DelivererOrderCard> {
  bool _isLoading = false;

  void _startDelivery() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);
    
    try {
      // 1. Actualizar Firestore
      await OrderService().updateOrderStatus(widget.order.id, OrderStatus.enCamino);
      
      // 2. Iniciar GPS (Heartbeat)
      LocationService().startTracking(auth.userId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Ruta iniciada! Ve a la pestaña "Ruta" para ver el mapa.')),
        );
      }
    } catch (e) {
      print('Error al iniciar ruta: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAsEntregado() async {
    setState(() => _isLoading = true);
    try {
      await OrderService().updateOrderStatus(widget.order.id, OrderStatus.entregado);
      
      // Detener emisión de GPS
      LocationService().stopTracking();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pedido entregado con éxito!')),
        );
      }
    } catch (e) {
      print('Error al finalizar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinamos qué botón mostrar según el estado real de Firestore
    bool enCamino = widget.order.status == OrderStatus.enCamino;
    bool entregado = widget.order.status == OrderStatus.entregado;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: enCamino ? Colors.orange[100] : AppColors.primary.withOpacity(0.1),
                child: Icon(
                  enCamino ? Icons.delivery_dining : Icons.shopping_bag,
                  color: enCamino ? Colors.orange : AppColors.primary,
                ),
              ),
              title: Text('Orden #${widget.order.id.substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Estado: ${widget.order.status.displayName}'),
              trailing: Text('S/ ${widget.order.total.toStringAsFixed(2)}', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (entregado)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Entregado', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                ],
              )
            else if (enCamino)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _markAsEntregado,
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: const Text('Marcar como Entregado', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startDelivery,
                  icon: const Icon(Icons.directions_bike, color: Colors.white),
                  label: const Text('Aceptar y Empezar Ruta', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
