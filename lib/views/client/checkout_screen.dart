import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'efectivo';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);
    try {
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Capture Location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

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
        customerLocation: GeoPoint(position.latitude, position.longitude),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar pedido: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
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
              Container(
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
                        'Por favor, realiza el pago al número 987 654 321 y envía tu pedido.',
                        style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            const Text('Notas adicionales', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Ej: Sin servilletas, timbre malogrado...'),
            ),
            
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar Pedido'),
            ),
          ],
        ),
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
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!, width: 2),
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
}
