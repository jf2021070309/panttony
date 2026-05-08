import 'package:flutter/material.dart';
import '../models/product.dart';

class MenuProvider with ChangeNotifier {
  final List<Product> _products = [
    // Queso
    Product(
      id: 'q1',
      name: 'Tres Quesos',
      description: 'Deliciosa combinación de tres tipos de queso fundido.',
      price: 4.00,
      imageUrl: '',
      category: ProductCategory.queso,
    ),
    Product(
      id: 'q2',
      name: 'Bollito de Queso',
      description: 'Bollito suave relleno de queso artesanal.',
      price: 3.00,
      imageUrl: '',
      category: ProductCategory.queso,
    ),
    Product(
      id: 'q3',
      name: 'Queso con Aceituna',
      description: 'Queso artesanal con trozos de aceituna seleccionada.',
      price: 3.50,
      imageUrl: '',
      category: ProductCategory.queso,
    ),
    Product(
      id: 'q4',
      name: 'Queso Tradicional',
      description: 'La clásica empanada de queso de la casa.',
      price: 2.50,
      imageUrl: '',
      category: ProductCategory.queso,
    ),
    // Criollas
    Product(
      id: 'c1',
      name: 'Rocoto Relleno',
      description: 'Sabor arequipeño tradicional en una empanada.',
      price: 7.50,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c2',
      name: 'Súper Triple',
      description: 'Tres rellenos en uno, para los más hambrientos.',
      price: 7.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c3',
      name: 'Lomito Saltado',
      description: 'Nuestro plato bandera envuelto en masa artesanal.',
      price: 6.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c4',
      name: 'Adobo de Chancho',
      description: 'Sabor tradicional de adobo cocido a fuego lento.',
      price: 6.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c5',
      name: 'Pollo con Verduras',
      description: 'Ligera y sabrosa, pollo con vegetales frescos.',
      price: 6.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c6',
      name: 'Ají de Pollo',
      description: 'Cremoso y con el toque justo de ají amarillo.',
      price: 6.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c7',
      name: 'Chorizo',
      description: 'Chorizo ahumado con especias de la casa.',
      price: 6.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
    Product(
      id: 'c8',
      name: 'Tradicional Triple/Carne/Pollo',
      description: 'Las favoritas de siempre: carne, pollo o triple.',
      price: 5.00,
      imageUrl: '',
      category: ProductCategory.criolla,
    ),
  ];

  final Map<String, int> _cart = {};

  List<Product> get products => _products;
  Map<String, int> get cart => _cart;

  List<Product> getProductsByCategory(ProductCategory category) {
    return _products.where((p) => p.category == category).toList();
  }

  void addToCart(String productId) {
    if (_cart.containsKey(productId)) {
      _cart[productId] = _cart[productId]! + 1;
    } else {
      _cart[productId] = 1;
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    if (_cart.containsKey(productId)) {
      if (_cart[productId]! > 1) {
        _cart[productId] = _cart[productId]! - 1;
      } else {
        _cart.remove(productId);
      }
      notifyListeners();
    }
  }

  double get total {
    double sum = 0;
    _cart.forEach((id, qty) {
      final product = _products.firstWhere((p) => p.id == id);
      sum += product.price * qty;
    });
    return sum;
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      notifyListeners();
    }
  }

  void deleteProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }
}
