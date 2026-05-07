import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';

class LocationSocketManager {
  WebSocketChannel? _channel;
  final String _url;
  final Function(double lat, double lng) onLocationReceived;

  LocationSocketManager({
    required String wsUrl,
    required this.onLocationReceived,
  }) : _url = wsUrl;

  void connect(String orderId, String role) {
    // Canal exclusivo por pedido: ws://tuserver.com/tracking/order123
    _channel = WebSocketChannel.connect(
      Uri.parse('$_url/tracking/$orderId?role=$role'),
    );

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        onLocationReceived(
          data['lat'] as double,
          data['lng'] as double,
        );
      },
      onError: (error) => _reconnect(orderId, role),
      onDone: () => print('WebSocket cerrado'),
    );
  }

  // Repartidor emite su ubicación
  void sendLocation(double lat, double lng, String orderId) {
    _channel?.sink.add(jsonEncode({
      'type': 'location_update',
      'orderId': orderId,
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  void _reconnect(String orderId, String role) {
    Future.delayed(const Duration(seconds: 3), () {
      connect(orderId, role);
    });
  }

  void disconnect() => _channel?.sink.close();
}
