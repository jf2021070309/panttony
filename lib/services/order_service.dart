import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/order.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createOrder(OrderModel order) async {
    final docRef = await _firestore.collection('pedidos').add(order.toMap());
    return docRef.id;
  }

  Stream<List<OrderModel>> getPendingOrders() {
    return _firestore
        .collection('pedidos')
        .where('status', isEqualTo: 'pendiente')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _firestore.collection('pedidos').doc(orderId).update({
      'status': status.name,
    });
  }

  Future<void> assignDeliverer(String orderId, String delivererId) async {
    await _firestore.collection('pedidos').doc(orderId).update({
      'delivererId': delivererId,
      'status': OrderStatus.asignado.name,
    });
  }
}
