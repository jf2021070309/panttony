import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import '../services/websocket_manager.dart';

class TrackingMapWidget extends StatefulWidget {
  final LatLng clienteDestino;
  final String orderId;
  final bool isRepartidor;

  const TrackingMapWidget({
    super.key,
    required this.clienteDestino,
    required this.orderId,
    required this.isRepartidor,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget>
    with SingleTickerProviderStateMixin {

  final Completer<GoogleMapController> _mapController = Completer();
  late AnimationController _animController;
  late Animation<double> _latAnim;
  late Animation<double> _lngAnim;

  LatLng _motoPos = const LatLng(-12.046374, -77.042793); // Lima Initial
  LatLng _prevPos = const LatLng(-12.046374, -77.042793);
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  BitmapDescriptor? _motoIcon;
  late LocationSocketManager _socket;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadMotoIcon();
    _connectSocket();
  }

  Future<void> _loadMotoIcon() async {
    // Note: User needs to add this asset
    try {
      _motoIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/moto_icon.png',
      );
    } catch (e) {
      _motoIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  void _connectSocket() {
    _socket = LocationSocketManager(
      wsUrl: 'wss://your-websocket-server.com', // Update with actual URL
      onLocationReceived: (lat, lng) {
        _animateMarkerTo(LatLng(lat, lng));
        _updateRoute(LatLng(lat, lng), widget.clienteDestino);
      },
    );
    _socket.connect(widget.orderId, widget.isRepartidor ? 'driver' : 'client');
  }

  void _animateMarkerTo(LatLng newPos) {
    _prevPos = _motoPos;

    _latAnim = Tween<double>(
      begin: _prevPos.latitude,
      end: newPos.latitude,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _lngAnim = Tween<double>(
      begin: _prevPos.longitude,
      end: newPos.longitude,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _animController.reset();
    _animController.forward();

    _animController.addListener(() {
      setState(() {
        _motoPos = LatLng(_latAnim.value, _lngAnim.value);
        _updateMarkers();
      });
    });
  }

  void _updateMarkers() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('moto'),
          position: _motoPos,
          icon: _motoIcon ?? BitmapDescriptor.defaultMarker,
          rotation: _getBearing(_prevPos, _motoPos),
          anchor: const Offset(0.5, 0.5),
          infoWindow: const InfoWindow(title: '🏍️ Repartidor en camino'),
        ),
        Marker(
          markerId: const MarkerId('destino'),
          position: widget.clienteDestino,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: '📍 Tu ubicación'),
        ),
      };
    });
  }

  double _getBearing(LatLng from, LatLng to) {
    double lat1 = from.latitude * (math.pi / 180);
    double lat2 = to.latitude * (math.pi / 180);
    double dLng = (to.longitude - from.longitude) * (math.pi / 180);
    double y = math.sin(dLng) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
                math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  Future<void> _updateRoute(LatLng origin, LatLng destination) async {
    const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    if (apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') return;

    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'].isNotEmpty) {
        final points = PolylinePoints.decodePolyline(
          data['routes'][0]['overview_polyline']['points'],
        );
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('ruta'),
              points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              color: const Color(0xFFD4830A),
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _motoPos,
        zoom: 15.0,
      ),
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (controller) => _mapController.complete(controller),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _socket.disconnect();
    super.dispose();
  }
}
