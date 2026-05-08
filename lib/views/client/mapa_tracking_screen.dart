import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animarker/flutter_map_marker_animation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';

class MapaTrackingScreen extends StatefulWidget {
  final String repartidorId;
  final LatLng destinoCliente;

  const MapaTrackingScreen({
    required this.repartidorId,
    required this.destinoCliente,
    super.key,
  });

  @override
  State<MapaTrackingScreen> createState() => _MapaTrackingScreenState();
}

class _MapaTrackingScreenState extends State<MapaTrackingScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  BitmapDescriptor? _motoIcon;

  LatLng _motoPos = const LatLng(-12.046374, -77.042793);
  double _bearing = 0.0;
  LatLng? _ultimaPosRuta;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  StreamSubscription<DocumentSnapshot>? _firestoreSub;

  static const String googleMapsApiKey =
      'AIzaSyCLY0TIyUVCQKO0Wd8PgPg8dfeCSPOTee0';

  @override
  void initState() {
    super.initState();
    _cargarIconos();
    _iniciarStreamFirestore();
  }

  Future<void> _cargarIconos() async {
    _motoIcon = await _crearIconoMoto();
    _actualizarMarcadores();
  }

  Future<BitmapDescriptor> _crearIconoMoto() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(100, 100);

    final bgPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, borderPaint);

    final textPainter = TextPainter(
      text: const TextSpan(text: '🏍️', style: TextStyle(fontSize: 40)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _iniciarStreamFirestore() {
    _firestoreSub = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.repartidorId)
        .snapshots()
        .listen((snap) {
          if (!snap.exists || snap.data() == null) return;
          final data = snap.data()!;
          final geo = data['ubicacionActual'] as GeoPoint?;
          if (geo == null) return;

          final newPos = LatLng(geo.latitude, geo.longitude);
          _bearing = _calcularBearing(_motoPos, newPos);
          _motoPos = newPos;

          _actualizarMarcadores();
          _moverCamaraSuave(newPos);

          if (_ultimaPosRuta == null ||
              _distanciaMetros(_ultimaPosRuta!, newPos) > 50) {
            _actualizarRuta(newPos);
            _ultimaPosRuta = newPos;
          }
        });
  }

  void _actualizarMarcadores() {
    if (!mounted) return;
    setState(() {
      _markers = {
        RippleMarker(
          markerId: const MarkerId('moto'),
          position: _motoPos,
          icon: _motoIcon ?? BitmapDescriptor.defaultMarker,
          rotation: _bearing,
          anchor: const Offset(0.5, 0.5),
          flat: true,
        ),
        Marker(
          markerId: const MarkerId('destino'),
          position: widget.destinoCliente,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      };
    });
  }

  Future<void> _moverCamaraSuave(LatLng newPos) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: newPos, zoom: 17, bearing: _bearing, tilt: 45),
      ),
    );
  }

  Future<void> _actualizarRuta(LatLng origen) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origen.latitude},${origen.longitude}'
      '&destination=${widget.destinoCliente.latitude},${widget.destinoCliente.longitude}'
      '&key=$googleMapsApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body);

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final points = routes[0]['overview_polyline']['points'] as String;

      // ✅ FIX: Usar como método estático, sin instanciar ni pasar apiKey
      final List<PointLatLng> decoded = PolylinePoints.decodePolyline(points);

      final List<LatLng> routeCoords = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      if (!mounted) return;
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: routeCoords,
            color: AppColors.primary,
            width: 5,
            jointType: JointType.round,
          ),
        };
      });
    } catch (e) {
      debugPrint('Error obteniendo ruta: $e');
    }
  }

  double _calcularBearing(LatLng from, LatLng to) {
    double lat1 = from.latitude * math.pi / 180;
    double lon1 = from.longitude * math.pi / 180;
    double lat2 = to.latitude * math.pi / 180;
    double lon2 = to.longitude * math.pi / 180;

    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    double brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  double _distanciaMetros(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rastreo de Pedido')),
      body: Animarker(
        mapId: _controller.future.then<int>((value) => value.mapId),
        markers: _markers,
        duration: const Duration(milliseconds: 1200),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _motoPos, zoom: 15),
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (controller) {
            _controller.complete(controller);
            _mapController = controller; // ✅ FIX: asignar _mapController
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
