import 'dart:ui';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../widgets/tracking_map.dart';

class OrderStatusScreen extends StatefulWidget {
  final Map<String, dynamic>? order;
  final String? orderId;

  const OrderStatusScreen({super.key, this.order, this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  // Usaremos un Stream para que la pantalla reaccione a cambios en el pedido (como cuando se asigna repartidor)
  late Stream<DocumentSnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    final id = widget.orderId ?? widget.order?['id'];
    _orderStream = FirebaseFirestore.instance.collection('pedidos').doc(id).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.orange)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorState("No encontramos los detalles de tu pedido");
        }

        final orderData = snapshot.data!.data() as Map<String, dynamic>;
        final String orderId = snapshot.data!.id;
        
        // Extraemos datos reales del pedido
        final GeoPoint? geoDestino = orderData['customerLocation'];
        final LatLng destino = geoDestino != null 
            ? LatLng(geoDestino.latitude, geoDestino.longitude)
            : const LatLng(-18.0135, -70.2510); // Fallback por si acaso

        final String? delivererId = orderData['delivererId'];
        final String status = orderData['status'] ?? 'pendiente';

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // MAPA DE TRACKING
              Positioned.fill(
                child: delivererId != null 
                  ? TrackingMapWidget(
                      clienteDestino: destino,
                      orderId: orderId,
                      repartidorId: delivererId,
                      isRepartidor: false,
                      debugMode: true, // Para testeo en tiempo real
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.orange, size: 60),
                          const SizedBox(height: 20),
                          const Text("Esperando repartidor...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Tu pedido #$orderId", style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
              ),

              // Botón Regresar
              Positioned(
                top: 50,
                left: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.white.withOpacity(0.2),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ),

              // Panel Deslizable
              _buildDraggablePanel(orderData, orderId, delivererId),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDraggablePanel(Map<String, dynamic> data, String orderId, String? delivererId) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(25),
            children: [
              Center(
                child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Text(
                delivererId == null ? "Buscando repartidor..." : "¡Tu pedido está cerca!", 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
              Text(
                delivererId == null ? "Estamos asignando al mejor Panttony para ti" : "El repartidor llegará en unos minutos", 
                style: const TextStyle(color: Colors.grey)
              ),
              const SizedBox(height: 25),
              
              if (delivererId != null) ...[
                // Info Repartidor (Solo si hay uno asignado)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 25, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Repartidor Asignado", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("Moto en camino", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => launchUrl(Uri.parse('tel:987654321')),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              Text("Orden #${orderId.substring(0, math.min(8, orderId.length))}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("S/ ${data['total']?.toString() ?? '0.00'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 50),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.white, fontSize: 18)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Regresar", style: TextStyle(color: Colors.orange)),
            )
          ],
        ),
      ),
    );
  }
}
