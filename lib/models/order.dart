import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pendiente,
  confirmado,
  en_preparacion,
  asignado,
  en_camino,
  entregado;

  String get displayName {
    switch (this) {
      case OrderStatus.pendiente: return 'Pendiente';
      case OrderStatus.confirmado: return 'Confirmado';
      case OrderStatus.en_preparacion: return 'En preparación';
      case OrderStatus.asignado: return 'Asignado';
      case OrderStatus.en_camino: return 'En camino';
      case OrderStatus.entregado: return 'Entregado';
    }
  }
}

class OrderModel {
  final String id;
  final String clientId;
  final List<OrderItem> items;
  final double total;
  final String paymentMethod; // 'efectivo' or 'yape'
  final String? yapeProofUrl;
  final GeoPoint customerLocation;
  final String? delivererId;
  final OrderStatus status;
  final DateTime createdAt;
  final String? notes;

  OrderModel({
    required this.id,
    required this.clientId,
    required this.items,
    required this.total,
    required this.paymentMethod,
    this.yapeProofUrl,
    required this.customerLocation,
    this.delivererId,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  factory OrderModel.fromFirestore(Map<String, dynamic> data, String id) {
    return OrderModel(
      id: id,
      clientId: data['clientId'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => OrderItem.fromMap(item))
          .toList(),
      total: (data['total'] ?? 0.0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'efectivo',
      yapeProofUrl: data['yapeProofUrl'],
      customerLocation: data['customerLocation'] ?? const GeoPoint(0, 0),
      delivererId: data['delivererId'],
      status: OrderStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pendiente'),
        orElse: () => OrderStatus.pendiente,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'paymentMethod': paymentMethod,
      'yapeProofUrl': yapeProofUrl,
      'customerLocation': customerLocation,
      'delivererId': delivererId,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'notes': notes,
    };
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      quantity: data['quantity'] ?? 0,
      price: (data['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }
}
