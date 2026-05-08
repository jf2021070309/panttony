import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';

class TrackingMapWidget extends StatefulWidget {
  final LatLng clienteDestino;
  final String orderId;
  final String repartidorId;
  final bool isRepartidor;
  final bool debugMode;

  const TrackingMapWidget({
    super.key,
    required this.clienteDestino,
    required this.orderId,
    required this.repartidorId,
    required this.isRepartidor,
    this.debugMode = false,
  });

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late LatLng _motoPos;
  LatLng? _rawMotoPos; 
  double _motoRotation = 0;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _fullRoutePoints = []; // La ruta completa recibida de Google
  BitmapDescriptor? _motoIcon;
  DateTime? _lastRouteUpdate;
  DateTime? _lastFirestoreUpdate; 
  StreamSubscription? _subscription;
  bool _isFirstPosition = true;

  late AnimationController _animController;
  
  final ValueNotifier<Offset> _joystickHandlePos = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _mapBearing = ValueNotifier(0.0);
  Timer? _joystickTimer;

  static const String _mapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "poi.park", "elementType": "labels.text.stroke", "stylers": [{"color": "#1b1b1b"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _motoPos = widget.clienteDestino; 
    _rawMotoPos = _motoPos;
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _loadMotoIcon();
    _initInitialRoute();
    _startTracking();
  }

  Future<void> _loadMotoIcon() async {
    try {
      final Uint8List markerIcon = await _getBytesFromAsset('assets/moto_icon.png', 110);
      _motoIcon = BitmapDescriptor.fromBytes(markerIcon);
    } catch (e) {
      _motoIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    _updateMarkers();
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _startTracking() {
    if (widget.isRepartidor && !widget.debugMode) {
      const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
      _subscription = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        _handleNewLocation(LatLng(pos.latitude, pos.longitude), animated: true);
      });
    } else if (!widget.isRepartidor) {
      _subscription = FirebaseFirestore.instance.collection('usuarios').doc(widget.repartidorId).snapshots().listen((snap) {
        if (snap.exists && mounted) {
          final data = snap.data() as Map<String, dynamic>;
          final GeoPoint? geo = data['ubicacionActual'];
          if (geo != null) {
            _handleNewLocation(LatLng(geo.latitude, geo.longitude), animated: true);
          }
        }
      });
    }
  }

  void _handleNewLocation(LatLng newPos, {bool animated = false}) {
    _rawMotoPos = newPos;
    LatLng finalPos = (widget.debugMode && widget.isRepartidor) ? _getSnappedPosition(newPos) : newPos;

    if (_isFirstPosition) {
      _isFirstPosition = false;
      setState(() {
        _motoPos = finalPos;
        _updateMarkers();
      });
      _mapController?.moveCamera(CameraUpdate.newLatLng(finalPos));
      _updateRouteIfNeeded(finalPos); 
      return;
    }

    if (animated) {
      _animateMoto(finalPos);
    } else {
      setState(() {
        if (_motoPos != finalPos) {
           _motoRotation = _calculateBearing(_motoPos, finalPos);
        }
        _motoPos = finalPos;
        _updateMarkers();
        _updatePolylinesLocal(); // Recorte local instantáneo
      });
    }

    _updateRouteIfNeeded(finalPos);
    if (widget.isRepartidor) {
      _broadcastLocation(finalPos);
    }
  }

  // Actualiza la línea azul localmente sin pedir nada a Google
  void _updatePolylinesLocal() {
    if (_fullRoutePoints.isEmpty) return;

    int nearestIdx = 0;
    double minDistance = double.infinity;

    // Buscamos el punto de la ruta más cercano a la moto
    for (int i = 0; i < _fullRoutePoints.length; i++) {
      double d = Geolocator.distanceBetween(
        _motoPos.latitude, _motoPos.longitude, 
        _fullRoutePoints[i].latitude, _fullRoutePoints[i].longitude
      );
      if (d < minDistance) {
        minDistance = d;
        nearestIdx = i;
      }
    }

    // Creamos una nueva lista que empieza desde la moto y sigue con el resto de la ruta
    List<LatLng> trimmedPoints = [_motoPos];
    trimmedPoints.addAll(_fullRoutePoints.sublist(nearestIdx + 1));

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('ruta_entrega'),
          points: trimmedPoints,
          color: AppColors.primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    });
  }

  LatLng _getSnappedPosition(LatLng p) {
    if (_fullRoutePoints.isEmpty) return p;

    LatLng closestPoint = _fullRoutePoints.first;
    double minDistance = double.infinity;

    for (int i = 0; i < _fullRoutePoints.length - 1; i++) {
      LatLng a = _fullRoutePoints[i];
      LatLng b = _fullRoutePoints[i + 1];
      LatLng pPrime = _projectPointOnSegment(p, a, b);
      
      double d = Geolocator.distanceBetween(p.latitude, p.longitude, pPrime.latitude, pPrime.longitude);
      if (d < minDistance) {
        minDistance = d;
        closestPoint = pPrime;
      }
    }
    return (minDistance < 40) ? closestPoint : p;
  }

  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    double x = p.latitude, y = p.longitude;
    double x1 = a.latitude, y1 = a.longitude;
    double x2 = b.latitude, y2 = b.longitude;
    double dx = x2 - x1, dy = y2 - y1;
    if (dx == 0 && dy == 0) return a;
    double t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
    if (t < 0) return a;
    if (t > 1) return b;
    return LatLng(x1 + t * dx, y1 + t * dy);
  }

  void _onJoystickMove(Offset delta) {
    double distance = delta.distance;
    if (distance > 40) {
      _joystickHandlePos.value = Offset.fromDirection(delta.direction, 40);
    } else {
      _joystickHandlePos.value = delta;
    }

    if (_joystickTimer == null || !_joystickTimer!.isActive) {
      _joystickTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
        if (_joystickHandlePos.value == Offset.zero) {
          timer.cancel();
          return;
        }
        double speed = 0.000005; 
        LatLng basePos = _rawMotoPos ?? _motoPos;
        LatLng nextRawPos = LatLng(
          basePos.latitude - (_joystickHandlePos.value.dy * speed),
          basePos.longitude + (_joystickHandlePos.value.dx * speed)
        );
        _handleNewLocation(nextRawPos, animated: false);
        _mapController?.moveCamera(CameraUpdate.newLatLng(_motoPos));
      });
    }
  }

  void _onJoystickEnd() {
    _joystickHandlePos.value = Offset.zero;
    _joystickTimer?.cancel();
  }

  void _animateMoto(LatLng target) {
    if (_motoPos == target) return;
    _motoRotation = _calculateBearing(_motoPos, target);
    final latTween = Tween<double>(begin: _motoPos.latitude, end: target.latitude);
    final lngTween = Tween<double>(begin: _motoPos.longitude, end: target.longitude);

    _animController.reset();
    final Animation<double> curve = CurvedAnimation(parent: _animController, curve: Curves.linear);
    
    _animController.addListener(() {
      if (mounted) {
        setState(() {
          _motoPos = LatLng(latTween.evaluate(curve), lngTween.evaluate(curve));
          _updateMarkers();
          _updatePolylinesLocal();
        });
      }
    });
    _animController.forward();
  }

  void _broadcastLocation(LatLng pos) {
    final now = DateTime.now();
    int intervalMs = widget.debugMode ? 500 : 4000;
    if (_lastFirestoreUpdate == null || now.difference(_lastFirestoreUpdate!).inMilliseconds >= intervalMs) {
      _lastFirestoreUpdate = now;
      FirebaseFirestore.instance.collection('usuarios').doc(widget.repartidorId).set({
        'ubicacionActual': GeoPoint(pos.latitude, pos.longitude),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _updateMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('moto'),
        position: _motoPos,
        rotation: _motoRotation,
        anchor: const Offset(0.5, 0.5),
        icon: _motoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('destino'),
        position: widget.clienteDestino,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * (math.pi / 180), lon1 = start.longitude * (math.pi / 180);
    double lat2 = end.latitude * (math.pi / 180), lon2 = end.longitude * (math.pi / 180);
    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  Future<void> _initInitialRoute() async {
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.repartidorId).get();
    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      final GeoPoint? pos = data['ubicacionActual'] as GeoPoint?;
      if (pos != null) {
        _handleNewLocation(LatLng(pos.latitude, pos.longitude));
      }
    }
  }

  void _updateRouteIfNeeded(LatLng currentPos) {
    int interval = widget.debugMode ? 4 : 15;
    if (_lastRouteUpdate == null || DateTime.now().difference(_lastRouteUpdate!).inSeconds > interval) {
      _lastRouteUpdate = DateTime.now();
      _fetchRoute(currentPos, widget.clienteDestino);
    }
  }

  Future<void> _fetchRoute(LatLng origin, LatLng dest) async {
    const String apiKey = 'AIzaSyCLY0TIyUVCQKO0Wd8PgPg8dfeCSPOTee0';
    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && mounted) {
        final decodedPoints = PolylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
        _fullRoutePoints = decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
        _updatePolylinesLocal();
      }
    } catch (e) {
      print('Error ruta: $e');
    }
  }

  void _recenterMap() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _motoPos, zoom: 17, bearing: 0, tilt: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.clienteDestino, zoom: 16.0),
          markers: _markers,
          polylines: _polylines,
          onMapCreated: (controller) {
            _mapController = controller;
            _mapController!.setMapStyle(_mapStyle);
          },
          onCameraMove: (position) => _mapBearing.value = position.bearing,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        
        Positioned(
          top: 60,
          right: 20,
          child: ValueListenableBuilder<double>(
            valueListenable: _mapBearing,
            builder: (context, bearing, _) {
              return GestureDetector(
                onTap: _recenterMap,
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -bearing * (math.pi / 180),
                      child: const Icon(Icons.explore_outlined, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        if (widget.debugMode && widget.isRepartidor)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onPanUpdate: (details) => _onJoystickMove(details.localPosition - const Offset(50, 50)),
                onPanEnd: (_) => _onJoystickEnd(),
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: ValueListenableBuilder<Offset>(
                    valueListenable: _joystickHandlePos,
                    builder: (context, pos, _) {
                      return Center(
                        child: Transform.translate(
                          offset: pos,
                          child: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                            ),
                            child: const Icon(Icons.directions_bike, color: Colors.white, size: 30),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        
        if (widget.debugMode)
          Positioned(
            top: 120,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("📦 Pedido: ${widget.orderId}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text("🛵 Repartidor: ${widget.repartidorId}", style: const TextStyle(color: Colors.white, fontSize: 11)),
                  Text("📍 Destino: ${widget.clienteDestino.latitude.toStringAsFixed(4)}, ${widget.clienteDestino.longitude.toStringAsFixed(4)}", 
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    _mapController?.dispose();
    _joystickTimer?.cancel();
    _joystickHandlePos.dispose();
    _mapBearing.dispose();
    super.dispose();
  }
}
