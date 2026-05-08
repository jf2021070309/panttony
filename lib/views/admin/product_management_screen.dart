import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../providers/menu_provider.dart';
import '../../widgets/product_card.dart';

class ProductManagementScreen extends StatelessWidget {
  const ProductManagementScreen({super.key});

  void _showProductForm(BuildContext context, {Product? product}) {
    final nameController = TextEditingController(text: product?.name);
    final descController = TextEditingController(text: product?.description);
    final priceController = TextEditingController(text: product?.price.toString());
    ProductCategory selectedCategory = product?.category ?? ProductCategory.queso;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product == null ? 'Nuevo Producto' : 'Editar Producto',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre (Ej: Tres Quesos)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio (S/)'),
                ),
                const SizedBox(height: 16),
                const Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Queso'),
                      selected: selectedCategory == ProductCategory.queso,
                      onSelected: (val) => setModalState(() => selectedCategory = ProductCategory.queso),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Criolla'),
                      selected: selectedCategory == ProductCategory.criolla,
                      onSelected: (val) => setModalState(() => selectedCategory = ProductCategory.criolla),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    final newProduct = Product(
                      id: product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      description: descController.text,
                      price: double.tryParse(priceController.text) ?? 0.0,
                      imageUrl: product?.imageUrl ?? '',
                      category: selectedCategory,
                    );

                    final provider = Provider.of<MenuProvider>(context, listen: false);
                    if (product == null) {
                      provider.addProduct(newProduct);
                    } else {
                      provider.updateProduct(newProduct);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(product == null ? 'Insertar Registro' : 'Guardar Cambios'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
      ),
      body: Consumer<MenuProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.products.length,
            itemBuilder: (context, index) {
              final product = provider.products[index];
              return ProductCard(
                product: product,
                isAdmin: true,
                onEdit: () => _showProductForm(context, product: product),
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('¿Eliminar?'),
                      content: Text('¿Estás seguro de eliminar ${product.name}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () {
                            provider.deleteProduct(product.id);
                            Navigator.pop(context);
                          },
                          child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        label: const Text('Insertar Registro'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
