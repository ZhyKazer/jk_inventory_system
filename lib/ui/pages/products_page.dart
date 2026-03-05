import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/ui/utils/color_utils.dart';
import 'package:jk_inventory_system/ui/widgets/forms/product_form_sheet.dart';

enum ProductSortTarget {
  productAlphabetical,
  categoryAlphabetical,
  qty,
}

enum SortDirection {
  asc,
  desc,
}

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
  ProductSortTarget _sortTarget = ProductSortTarget.categoryAlphabetical;
  SortDirection _sortDirection = SortDirection.asc;
  final Set<String> _selectedProductIds = <String>{};

  bool get _isSelectionMode => _selectedProductIds.isNotEmpty;

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

  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedProductIds.clear());
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    if (_selectedProductIds.isEmpty) return;

    final count = _selectedProductIds.length;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Products'),
        content: Text('Delete $count selected product(s)?'),
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

    if (shouldDelete != true) return;

    final idsToDelete = _selectedProductIds.toList(growable: false);
    for (final id in idsToDelete) {
      await widget.productProvider.delete(id);
    }

    if (!mounted) return;
    _clearSelection();
  }

  Future<void> _showProductStatus(
    BuildContext context, {
    required Product product,
    required String categoryName,
  }) {
    final qtyRemaining =
        widget.outingProvider.currentStock(product.id, UnitType.quantity);

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: $categoryName'),
            const SizedBox(height: 12),
            Text('Current Qty Remaining: ${qtyRemaining.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            Text('Capital Price: ${product.costPrice.toStringAsFixed(2)}'),
            Text('Selling Price: ${product.sellingPrice.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSortControls() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search products or category...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProductSortTarget>(
                  initialValue: _sortTarget,
                  decoration: const InputDecoration(
                    labelText: 'Sort Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ProductSortTarget.productAlphabetical,
                      child: Text('By Product'),
                    ),
                    DropdownMenuItem(
                      value: ProductSortTarget.categoryAlphabetical,
                      child: Text('By Category'),
                    ),
                    DropdownMenuItem(
                      value: ProductSortTarget.qty,
                      child: Text('By Qty'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortTarget = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<SortDirection>(
                  initialValue: _sortDirection,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SortDirection.asc,
                      child: Text('Asc'),
                    ),
                    DropdownMenuItem(
                      value: SortDirection.desc,
                      child: Text('Desc'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortDirection = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        final productIds = products.map((product) => product.id).toSet();
        _selectedProductIds.removeWhere((id) => !productIds.contains(id));
        final categoryById = {
          for (final category in categories) category.id: category,
        };
        final categoryNameById = {
          for (final category in categories) category.id: category.name,
        };

        if (products.isEmpty) {
          return const Center(
            child: Text('No products yet. Use + to add product.'),
          );
        }

        final unitFiltered = products.where((product) {
          if (_sortTarget == ProductSortTarget.qty) {
            final category = categoryById[product.categoryId];
            return category?.defaultUnit == UnitType.quantity;
          }

          return true;
        }).toList();

        final filtered = unitFiltered.where((product) {
          if (_query.isEmpty) return true;
          final nameMatch = product.name.toLowerCase().contains(_query);
          final categoryMatch =
              (categoryNameById[product.categoryId] ?? '').toLowerCase().contains(_query);
          return nameMatch || categoryMatch;
        }).toList();

        filtered.sort((left, right) {
          final leftName = left.name.toLowerCase();
          final rightName = right.name.toLowerCase();
          final leftCategory = (categoryNameById[left.categoryId] ?? '').toLowerCase();
          final rightCategory = (categoryNameById[right.categoryId] ?? '').toLowerCase();

          if (_sortTarget == ProductSortTarget.productAlphabetical) {
            return _sortDirection == SortDirection.asc
                ? leftName.compareTo(rightName)
                : rightName.compareTo(leftName);
          }

          if (_sortTarget == ProductSortTarget.qty) {
            final leftQty = widget.outingProvider.currentStock(
              left.id,
              UnitType.quantity,
            );
            final rightQty = widget.outingProvider.currentStock(
              right.id,
              UnitType.quantity,
            );

            final qtyCompare = _sortDirection == SortDirection.asc
                ? leftQty.compareTo(rightQty)
                : rightQty.compareTo(leftQty);
            if (qtyCompare != 0) return qtyCompare;
            return leftName.compareTo(rightName);
          }

          final categoryCompare = _sortDirection == SortDirection.asc
              ? leftCategory.compareTo(rightCategory)
              : rightCategory.compareTo(leftCategory);

          if (categoryCompare != 0) return categoryCompare;
          return leftName.compareTo(rightName);
        });

        if (filtered.isEmpty) {
          return Column(
            children: [
              _buildSearchAndSortControls(),
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
            _buildSearchAndSortControls(),
            if (_isSelectionMode)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedProductIds.length} selected',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _confirmDeleteSelected(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final isSelected = _selectedProductIds.contains(product.id);
                  CategoryMatchResult? category;
                  UnitType? categoryUnit;
                  for (final item in categories) {
                    if (item.id == product.categoryId) {
                      category = CategoryMatchResult(
                        id: item.id,
                        name: item.name,
                        colorHex: item.colorHex,
                      );
                      categoryUnit = item.defaultUnit;
                      break;
                    }
                  }

                  final unitToShow = categoryUnit ?? UnitType.quantity;
                  final stockValue = widget.outingProvider.currentStock(
                    product.id,
                    unitToShow,
                  );

                  return ListTile(
                    selected: isSelected,
                    onLongPress: () => _toggleSelection(product.id),
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(product.id);
                        return;
                      }

                      _showProductStatus(
                        context,
                        product: product,
                        categoryName: category?.name ?? 'No category',
                      );
                    },
                    leading: _isSelectionMode
                        ? Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          )
                        : null,
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
                          'In stock • ${unitToShow.label}: ${stockValue.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: _isSelectionMode
                              ? null
                              : categories.isEmpty
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
                          onPressed: _isSelectionMode
                              ? null
                              : () => _confirmDelete(context, product.id),
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
