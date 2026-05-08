import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/user_model.dart';

class SetupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initializeData() async {
    print('Iniciando carga de datos...');
    await _setupUsers();
    await _setupProducts();
    print('Carga de datos completada con éxito.');
  }

  Future<void> _setupUsers() async {
    final users = [
      UserModel(
        id: 'admin_panttony',
        name: 'Administrador Panttony',
        email: 'admin@panttony.com',
        phone: '953128593',
        password: 'admin123', // Tu password en Firestore
        role: UserRole.admin,
      ),
      UserModel(
        id: 'repartidor_01',
        name: 'Juan Repartidor',
        email: 'repartidor@panttony.com',
        phone: '900000001',
        password: '123',
        role: UserRole.repartidor,
      ),
      UserModel(
        id: 'cliente_01',
        name: 'Cliente Prueba',
        email: 'cliente@gmail.com',
        phone: '900000002',
        password: '123',
        role: UserRole.cliente,
      ),
    ];

    for (var user in users) {
      await _db.collection('usuarios').doc(user.id).set(user.toMap());
    }
  }

  Future<void> _setupProducts() async {
    final List<Product> products = [
      // --- EMPANADAS DE QUESO ---
      Product(
        id: 'q1',
        name: 'Tres Quesos',
        description: 'Queso mozzarella, paria, y fundido.',
        price: 4.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=500',
        category: ProductCategory.queso,
      ),
      Product(
        id: 'q2',
        name: 'Bollito de Queso',
        description: 'Masa levada rellena de queso paria.',
        price: 3.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=501',
        category: ProductCategory.queso,
      ),
      Product(
        id: 'q3',
        name: 'Q. con Aceituna',
        description: 'Masa hojaldre rápida, aceituna en rodajas, pasta y queso.',
        price: 3.50,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=502',
        category: ProductCategory.queso,
      ),
      Product(
        id: 'q4',
        name: 'Q. Tradicional',
        description: 'Masa hojaldre rápida rellena de queso.',
        price: 2.50,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=503',
        category: ProductCategory.queso,
      ),

      // --- EMPANADAS CRIOLLAS ---
      Product(
        id: 'c1',
        name: 'Rocoto Relleno',
        description: 'Masa quebrada rellena de carne en trozos, rocoto, cebolla, huevo, queso, maní, y pasas.',
        price: 7.50,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=504',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c2',
        name: 'Súper Triple',
        description: 'Masa quebrada rellena de pollo en trozos, jamonada de pollo y crema de queso.',
        price: 7.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=505',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c3',
        name: 'Lomito Saltado',
        description: 'Masa quebrada rellena de lomo en trozos, papas al hilo, cebolla y pimiento.',
        price: 6.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=506',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c4',
        name: 'Adobo de chancho',
        description: 'Masa quebrada rellena de cerdo en trozos, cebolla, ají amarillo, hierbabuena.',
        price: 6.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=507',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c5',
        name: 'Pollo con Verduras',
        description: 'Masa quebrada rellena de pollo en trozos, zanahoria, arvejas, morrón, vainitas y crema de mayonesa.',
        price: 6.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=508',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c6',
        name: 'Ají de Pollo',
        description: 'Masa quebrada rellena de pollo en trozos, crema de ají amarillo, huevo y aceituna.',
        price: 6.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=509',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c7',
        name: 'Tradicionales',
        description: 'Triple, Carne y Pollo.',
        price: 5.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=510',
        category: ProductCategory.criolla,
      ),
      Product(
        id: 'c8',
        name: 'Chorizo',
        description: 'Masa quebrada rellena de chorizo picado, cebolla, orégano.',
        price: 6.00,
        imageUrl: 'https://images.unsplash.com/photo-1559561853-08451507c73a?q=80&w=511',
        category: ProductCategory.criolla,
      ),
    ];

    for (var product in products) {
      await _db.collection('productos').doc(product.id).set(product.toMap());
    }
  }
}
