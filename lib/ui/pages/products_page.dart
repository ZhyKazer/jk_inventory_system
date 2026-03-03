import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/ui/utils/color_utils.dart';
import 'package:jk_inventory_system/ui/widgets/forms/product_form_sheet.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.productProvider,
    required this.categoryProvider,
    required this.outingProvider,
  });

  final ProductProvider productProvider;
  final CategoryProvider categoryProvider;
  final OutingProvider outingProvider;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      await widget.productProvider.delete(productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.productProvider,
        widget.categoryProvider,
        widget.outingProvider,
      ]),
      builder: (context, _) {
        final products = widget.productProvider.items;
        final categories = widget.categoryProvider.items;

        if (products.isEmpty) {
          return const Center(
            child: Text('No products yet. Use + to add product.'),
          );
        }

        final filtered = products.where((product) {
          if (_query.isEmpty) return true;
          final nameMatch = product.name.toLowerCase().contains(_query);
          final categoryMatch = categories
              .firstWhere(
                (c) => c.id == product.categoryId,
                orElse: () => Category(
                      id: '',
                      name: '',
                      colorHex: '',
                      defaultUnit: UnitType.quantity,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
              )
              .name
              .toLowerCase()
              .contains(_query);
          return nameMatch || categoryMatch;
        }).toList();

        if (filtered.isEmpty) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products or category...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('No products match your search.'),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search products or category...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final product = filtered[index];
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
                          'In stock • Qty: ${widget.outingProvider.currentStock(product.id, UnitType.quantity).toStringAsFixed(2)} • Kilo: ${widget.outingProvider.currentStock(product.id, UnitType.kilo).toStringAsFixed(2)}',
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
                                    provider: widget.productProvider,
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
              ),
            ),
          ],
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
