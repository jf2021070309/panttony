import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/websocket_manager.dart';

class DelivererOrdersScreen extends StatelessWidget {
  const DelivererOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Entregas'),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('delivererId', isEqualTo: authProvider.userId)
            .where('status', isEqualTo: 'asignado')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No tienes entregas pendientes'));

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
  bool _isDelivering = false;
  late LocationSocketManager _socket;

  @override
  void initState() {
    super.initState();
    _socket = LocationSocketManager(
      wsUrl: 'wss://your-websocket-server.com',
      onLocationReceived: (lat, lng) {}, // Not used by driver
    );
  }

  void _startDelivery() async {
    setState(() => _isDelivering = true);
    await OrderService().updateOrderStatus(widget.order.id, OrderStatus.en_camino);
    _socket.connect(widget.order.id, 'driver');
    
    // Start emitting location
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _socket.sendLocation(position.latitude, position.longitude, widget.order.id);
    });
  }

  void _markAsEntregado() async {
    await OrderService().updateOrderStatus(widget.order.id, OrderStatus.entregado);
    _socket.disconnect();
    if (mounted) setState(() => _isDelivering = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              title: Text('Entrega para: ${widget.order.clientId}'),
              subtitle: Text('Total: S/ ${widget.order.total.toStringAsFixed(2)}'),
              trailing: Icon(Icons.location_on, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            if (!_isDelivering)
              ElevatedButton(
                onPressed: _startDelivery,
                child: const Text('Aceptar y Empezar Ruta'),
              )
            else
              ElevatedButton(
                onPressed: _markAsEntregado,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: const Text('Marcar como Entregado'),
              ),
          ],
        ),
      ),
    );
  }
}
