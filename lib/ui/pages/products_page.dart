import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/ui/utils/color_utils.dart';
import 'package:jk_inventory_system/ui/widgets/forms/product_form_sheet.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({
    super.key,
    required this.productProvider,
    required this.categoryProvider,
    required this.outingProvider,
  });

  final ProductProvider productProvider;
  final CategoryProvider categoryProvider;
  final OutingProvider outingProvider;

  Future<void> _confirmDelete(BuildContext context, String productId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await productProvider.delete(productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        productProvider,
        categoryProvider,
        outingProvider,
      ]),
      builder: (context, _) {
        final products = productProvider.items;
        final categories = categoryProvider.items;

        if (products.isEmpty) {
          return const Center(
            child: Text('No products yet. Use + to add product.'),
          );
        }

        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, index) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final product = products[index];
            CategoryMatchResult? category;
            for (final item in categories) {
              if (item.id == product.categoryId) {
                category = CategoryMatchResult(
                  id: item.id,
                  name: item.name,
                  colorHex: item.colorHex,
                );
                break;
              }
            }

            return ListTile(
              title: Text(product.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category == null)
                    const Text('No category')
                  else
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: colorFromHex(category.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(category.name),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'In stock • Qty: ${outingProvider.currentStock(product.id, UnitType.quantity).toStringAsFixed(2)} • Kilo: ${outingProvider.currentStock(product.id, UnitType.kilo).toStringAsFixed(2)}',
                  ),
                ],
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    onPressed: categories.isEmpty
                        ? null
                        : () => showProductFormSheet(
                            context,
                            provider: productProvider,
                            categories: categories,
                            editing: product,
                          ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(context, product.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CategoryMatchResult {
  CategoryMatchResult({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  final String id;
  final String name;
  final String colorHex;
}
