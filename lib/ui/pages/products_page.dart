import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/ui/utils/color_utils.dart';
import 'package:jk_inventory_system/ui/widgets/forms/product_form_sheet.dart';

enum ProductSortTarget { productAlphabetical, categoryAlphabetical, qty }

enum SortDirection { asc, desc }

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
  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  String _query = '';
  ProductSortTarget _sortTarget = ProductSortTarget.categoryAlphabetical;
  SortDirection _sortDirection = SortDirection.asc;
  final Set<String> _selectedProductIds = <String>{};
  int _currentPage = 0;

  bool get _isSelectionMode => _selectedProductIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
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
    final qtyRemaining = widget.outingProvider.currentStock(
      product.id,
      UnitType.quantity,
    );

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Info Preview'),
        content: SingleChildScrollView(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        'BNM',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('PRODUCT INFO RECEIPT'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                if (product.imagePath != null && product.imagePath!.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: Image.file(
                          File(product.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (product.imagePath != null && product.imagePath!.isNotEmpty)
                  const SizedBox(height: 12),
                _receiptLine(
                  label: 'Product',
                  value: product.name,
                  emphasized: true,
                ),
                _receiptLine(label: 'Category', value: categoryName),
                _receiptLine(
                  label: 'Current Qty',
                  value: qtyRemaining.toStringAsFixed(2),
                ),
                _receiptLine(
                  label: 'Capital Price',
                  value: product.costPrice.toStringAsFixed(2),
                ),
                _receiptLine(
                  label: 'Selling Price',
                  value: product.sellingPrice.toStringAsFixed(2),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'System-generated receipt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _receiptLine({
    required String label,
    required String value,
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
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
        final categoryNameById = {
          for (final category in categories) category.id: category.name,
        };

        if (products.isEmpty) {
          return const Center(
            child: Text('No products yet. Use + to add product.'),
          );
        }

        final filtered = products.where((product) {
          if (_query.isEmpty) return true;
          final nameMatch = product.name.toLowerCase().contains(_query);
          final categoryMatch = (categoryNameById[product.categoryId] ?? '')
              .toLowerCase()
              .contains(_query);
          return nameMatch || categoryMatch;
        }).toList();

        filtered.sort((left, right) {
          final leftName = left.name.toLowerCase();
          final rightName = right.name.toLowerCase();
          final leftCategory = (categoryNameById[left.categoryId] ?? '')
              .toLowerCase();
          final rightCategory = (categoryNameById[right.categoryId] ?? '')
              .toLowerCase();

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
                child: Center(child: Text('No products match your search.')),
              ),
            ],
          );
        }

        final totalPages = (filtered.length / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        return Column(
          children: [
            _buildSearchAndSortControls(),
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'Page ${_currentPage + 1} of $totalPages',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      'Swipe to change page',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (_isSelectionMode)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: totalPages,
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * _pageSize;
                  final end = (start + _pageSize > filtered.length)
                      ? filtered.length
                      : start + _pageSize;
                  final pageItems = filtered.sublist(start, end);

                  return ListView.separated(
                    itemCount: pageItems.length,
                    separatorBuilder: (_, index) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final product = pageItems[index];
                      final isSelected = _selectedProductIds.contains(
                        product.id,
                      );
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

                      const unitToShow = UnitType.quantity;
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
                            : _buildProductPreview(product),
                        title: Text(product.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (category == null)
                              const Text('No category')
                            else
                              Builder(
                                builder: (context) {
                                  final categoryColor = colorFromHex(
                                    category!.colorHex,
                                  );
                                  final useDarkText =
                                      ThemeData.estimateBrightnessForColor(
                                        categoryColor,
                                      ) ==
                                      Brightness.light;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: categoryColor.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                        color: useDarkText
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : categoryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
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
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductPreview(Product product) {
    if (product.imagePath == null || product.imagePath!.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.inventory_2_outlined));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.file(
          File(product.imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined, size: 20),
          ),
        ),
      ),
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
