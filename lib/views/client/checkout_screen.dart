import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/menu_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with SingleTickerProviderStateMixin {
  String _paymentMethod = 'efectivo';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  String _currentAddress = "Cargando dirección...";
  bool _showTooltip = false;
  bool _isGeocoding = false;

  late AnimationController _tooltipController;
  late Animation<double> _tooltipAnimation;

  @override
  void initState() {
    super.initState();
    _tooltipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tooltipAnimation = CurvedAnimation(
      parent: _tooltipController,
      curve: Curves.easeOutBack,
    );
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // 1. Intentamos obtener la última posición conocida para rapidez
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        final lastLatLng = LatLng(lastPos.latitude, lastPos.longitude);
        setState(() => _selectedLocation = lastLatLng);
        _mapController?.moveCamera(CameraUpdate.newLatLngZoom(lastLatLng, 17));
        _getAddressFromLatLng(lastLatLng);
      }

      // 2. Obtenemos la posición actual exacta
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      final latLng = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() => _selectedLocation = latLng);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));
        _getAddressFromLatLng(latLng);
      }
    } catch (e) {
      print('Error inicializando ubicación: $e');
    }
  }

  Future<void> _getAddressFromLatLng(LatLng pos) async {
    setState(() {
      _isGeocoding = true;
      _showTooltip = true;
      _currentAddress = "Buscando dirección...";
    });
    _tooltipController.forward(from: 0.0);

    // Usaremos OpenStreetMap (Nominatim) - ¡Es GRATIS y no requiere API Key!
    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'PanttonyApp/1.0', // Es obligatorio para OpenStreetMap
          'Accept-Language': 'es', // Para que la dirección salga en español
        },
      );
      
      final data = json.decode(response.body);
      
      if (data['display_name'] != null) {
        final addressData = data['address'];
        
        // Extraemos los componentes clave para una dirección peruana
        String road = addressData['road'] ?? addressData['pedestrian'] ?? "";
        String houseNumber = addressData['house_number'] ?? ""; // Aquí suele venir el Mz/Lt en OSM
        String suburb = addressData['suburb'] ?? addressData['neighbourhood'] ?? addressData['residential'] ?? "";
        
        String finalAddr = "";
        
        // Si tenemos calle y número/lote
        if (road.isNotEmpty) {
          finalAddr = houseNumber.isNotEmpty ? "$road $houseNumber" : road;
        } else if (houseNumber.isNotEmpty) {
          finalAddr = houseNumber; // A veces solo hay Mz/Lt
        }
        
        // Añadimos la Urbanización/Barrio si existe
        if (suburb.isNotEmpty) {
          finalAddr = finalAddr.isNotEmpty ? "$finalAddr, $suburb" : suburb;
        }
        
        // Si al final quedó vacío, usamos el nombre genérico corto
        if (finalAddr.isEmpty) {
          finalAddr = data['display_name'].split(',')[0];
        }

        setState(() {
          _currentAddress = finalAddr;
          _isGeocoding = false;
        });
      } else {
        // Si hay un error (ej: REQUEST_DENIED), lo imprimimos para depurar
        print('Error de Geocoding Google: ${data['status']} - ${data['error_message'] ?? 'Sin mensaje'}');
        
        setState(() {
          // Si falla la dirección, mostramos las coordenadas como respaldo
          _currentAddress = "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
          _isGeocoding = false;
        });
      }
    } catch (e) {
      print('Error de conexión en Geocoding: $e');
      setState(() {
        _currentAddress = "Error de red";
        _isGeocoding = false;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona tu ubicación en el mapa.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final order = OrderModel(
        id: '',
        clientId: authProvider.userId ?? 'anonimo',
        items: menuProvider.cart.entries.map((e) {
          final p = menuProvider.products.firstWhere((prod) => prod.id == e.key);
          return OrderItem(
            productId: e.key,
            productName: p.name,
            quantity: e.value,
            price: p.price,
          );
        }).toList(),
        total: menuProvider.total,
        paymentMethod: _paymentMethod,
        customerLocation: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        status: OrderStatus.pendiente,
        createdAt: DateTime.now(),
        notes: _notesController.text,
      );

      final orderId = await OrderService().createOrder(order);
      menuProvider.clearCart();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/status', arguments: orderId);
      }
    } catch (e) {
      print('Error fatal en checkout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar pedido: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Finalizar Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Dónde entregamos?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Mueve el mapa para situar el punto exacto', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            
            // MAPA DE SELECCIÓN PROFESIONAL
            SizedBox(
              height: 350,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ?? const LatLng(-18.0135, -70.2510), // Tacna por defecto
                      zoom: 17,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onCameraMove: (position) {
                      setState(() {
                        _selectedLocation = position.target;
                        _showTooltip = false;
                      });
                      _tooltipController.reverse();
                    },
                    onCameraIdle: () {
                      if (_selectedLocation != null) {
                        _getAddressFromLatLng(_selectedLocation!);
                      }
                    },
                    onTap: (latLng) {
                      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
                    },
                    // ESTO ES CLAVE: Permite que el mapa funcione dentro de un scroll
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                  ),
                  
                  // PIN CENTRAL ESTILO RAPPI/UBER
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 35), // Ajuste para que la punta del pin sea el centro
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // TOOLTIP ANIMADO
                          ScaleTransition(
                            scale: _tooltipAnimation,
                            child: _showTooltip ? Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Punto de entrega',
                                          style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _currentAddress,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
                                ],
                              ),
                            ) : const SizedBox.shrink(),
                          ),
                          
                          // EL PIN (Círculo con punto)
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          // "Sombrilla" o palito del pin
                          Container(
                            width: 2,
                            height: 15,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // BOTÓN MI UBICACIÓN
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton.small(
                      backgroundColor: Colors.white,
                      onPressed: _initLocation,
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Método de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPaymentOption('efectivo', 'Efectivo', Icons.money),
                  const SizedBox(height: 12),
                  _buildPaymentOption('yape', 'Yape', Icons.qr_code_scanner),
                  
                  if (_paymentMethod == 'yape') ...[
                    const SizedBox(height: 24),
                    _buildYapeInfo(),
                  ],
                  
                  const SizedBox(height: 32),
                  const Text('Notas adicionales', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej: Puerta negra, llamar al llegar...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _isSubmitting ? null : _submitOrder,
                      child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Confirmar Pedido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildYapeInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.purple),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Yapea al 987 654 321 y envía la captura por WhatsApp al confirmar.',
              style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String val, String label, IconData icon) {
    bool isSelected = _paymentMethod == val;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = val),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tooltipController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
