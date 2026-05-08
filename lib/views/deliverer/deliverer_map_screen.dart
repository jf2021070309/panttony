import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/tracking_map.dart';
import '../../core/theme.dart';

class DelivererMapScreen extends StatefulWidget {
  const DelivererMapScreen({super.key});

  @override
  State<DelivererMapScreen> createState() => _DelivererMapScreenState();
}

class _DelivererMapScreenState extends State<DelivererMapScreen> {
  LatLng? _initialPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final newPos = LatLng(position.latitude, position.longitude);
      
      if (!mounted) return;
      setState(() {
        _initialPosition = newPos;
      });

      // ¡AQUÍ ESTÁ EL TRUCO!: Movemos la cámara manualmente
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newPos, 16),
        );
      }
    } catch (e) {
      print('Error obteniendo ubicación inicial: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.userId;

    if (userId == null) return const Scaffold(body: Center(child: Text('Error de sesión')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta de Entrega', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('delivererId', isEqualTo: userId)
            .where('status', isEqualTo: 'enCamino')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _initialPosition == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoActiveOrder();
          }

          final orderData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final String orderId = snapshot.data!.docs.first.id;
          final GeoPoint? destino = orderData['customerLocation'] as GeoPoint?;

          if (destino == null) {
            return const Center(child: Text('El pedido no tiene coordenadas de entrega.'));
          }

          return TrackingMapWidget(
            orderId: orderId,
            repartidorId: userId,
            isRepartidor: true,
            debugMode: true, // Habilitar controles manuales para testeo
            clienteDestino: LatLng(destino.latitude, destino.longitude),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCoordinatesModal(context),
        label: const Text('Mi Posición', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.my_location, color: Colors.white),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showCoordinatesModal(BuildContext context) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.gps_fixed, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Coordenadas GPS'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCoordRow('Latitud', position.latitude.toStringAsFixed(6)),
              const SizedBox(height: 10),
              _buildCoordRow('Longitud', position.longitude.toStringAsFixed(6)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () => _openExternalMaps(position.latitude, position.longitude),
              icon: const Icon(Icons.map, color: Colors.white, size: 18),
              label: const Text('Abrir en Google Maps', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la ubicación exacta.')),
      );
    }
  }

  void _openExternalMaps(double lat, double lng) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps.')),
      );
    }
  }

  Widget _buildCoordRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildNoActiveOrder() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialPosition ?? const LatLng(-12.046374, -77.042793),
            zoom: 15,
          ),
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 30),
                SizedBox(height: 10),
                Text(
                  'No tienes entregas activas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Inicia un reparto en la pestaña "Entregas" para ver la ruta aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
