import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/ui/utils/color_utils.dart';
import 'package:jk_inventory_system/ui/widgets/forms/category_form_sheet.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({
    super.key,
    required this.categoryProvider,
    required this.productProvider,
  });

  final CategoryProvider categoryProvider;
  final ProductProvider productProvider;

  Future<void> _confirmDelete(
    BuildContext context,
    Category category,
  ) async {
    final usedByProduct = productProvider.items.any(
      (item) => item.categoryId == category.id,
    );

    if (!categoryProvider.canDelete(
      category.id,
      isUsedByProduct: usedByProduct,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete category because products are using it.'),
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete ${category.name}?'),
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
      await categoryProvider.delete(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: AnimatedBuilder(
        animation: categoryProvider,
        builder: (context, _) {
          final items = categoryProvider.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('No categories yet. Tap + to add one.'),
            );
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, index) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final category = items[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorFromHex(category.colorHex),
                ),
                title: Text(category.name),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      onPressed: () => showCategoryFormSheet(
                        context,
                        provider: categoryProvider,
                        editing: category,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, category),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryFormSheet(
          context,
          provider: categoryProvider,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
