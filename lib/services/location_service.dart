import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;

  void startTracking(String userId) async {
    try {
      print('Solicitando permisos de GPS...');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) return;

      await stopTracking();

      print('Iniciando rastreo por Latido (Máxima Compatibilidad)...');

      // Usamos un Timer manual en lugar de un Stream. 
      // Esto es mucho más estable y no bloquea el hilo principal.
      _mockTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        try {
          // Pedimos la ubicación una sola vez (one-shot)
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true, // Forzamos modo nativo para evitar DEVELOPER_ERROR
            ),
          ).timeout(const Duration(seconds: 5));

          print('Latido GPS: ${position.latitude}, ${position.longitude}');
          
          FirebaseFirestore.instance.collection('usuarios').doc(userId).update({
            'ubicacionActual': GeoPoint(position.latitude, position.longitude),
            'heading': position.heading,
            'speed': position.speed,
            'lastUpdate': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Latido fallido (reintentando en 10s): $e');
        }
      });

    } catch (e) {
      print('Error en inicio de tracking: $e');
    }
  }

  Timer? _mockTimer;

  Future<void> stopTracking() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    await _positionStream?.cancel();
    _positionStream = null;
    print('Tracking detenido.');
  }
}
