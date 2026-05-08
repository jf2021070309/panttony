import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/menu_provider.dart';
import '../../widgets/product_card.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Panttony Artistic Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://www.transparenttextures.com/patterns/pinstriped-suit.png'), // Subtle texture
                  opacity: 0.05,
                ),
              ),
              child: Column(
                children: [
                  // Logo Style
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E2723),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Panttony',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'EMPANADAS',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3E2723),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: const Color(0xFF3E2723),
                    child: const Text(
                      '¡SABOR QUE TE ENCANTA!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'HECHAS CON INGREDIENTES FRESCOS Y DE CALIDAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF3E2723),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons (Logout/Cart)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Provider.of<AuthProvider>(context, listen: false).logout();
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    icon: const Icon(Icons.logout, color: Color(0xFF3E2723)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/cart'),
                    icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF3E2723), size: 28),
                  ),
                ],
              ),
            ),
          ),

          // Menu List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: Consumer<MenuProvider>(
              builder: (context, provider, child) {
                return SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),
                    _buildCategoryHeader('EMPANADAS DE QUESO'),
                    ...provider.getProductsByCategory(ProductCategory.queso)
                        .map((p) => ProductCard(product: p)),
                    
                    const SizedBox(height: 40),
                    _buildCategoryHeader('EMPANADAS CRIOLLAS'),
                    ...provider.getProductsByCategory(ProductCategory.criolla)
                        .map((p) => ProductCard(product: p)),
                    
                    const SizedBox(height: 120),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/cart'),
        label: Consumer<MenuProvider>(
          builder: (context, provider, child) => Text(
            'MI CARRITO: S/ ${provider.total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        icon: const Icon(Icons.shopping_basket),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chevron_right, color: AppColors.primary),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Icon(Icons.chevron_left, color: AppColors.primary),
        ],
      ),
    );
  }
}
