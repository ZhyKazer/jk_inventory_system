import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';

class CreateBatchPage extends StatefulWidget {
  const CreateBatchPage({
    super.key,
    required this.stockBatchProvider,
    required this.productProvider,
    required this.categoryProvider,
  });

  final StockBatchProvider stockBatchProvider;
  final ProductProvider productProvider;
  final CategoryProvider categoryProvider;

  @override
  State<CreateBatchPage> createState() => _CreateBatchPageState();
}

class _CreateBatchPageState extends State<CreateBatchPage> {
  final List<_BatchItemDraft> _rows = [];
  bool _isSaving = false;

  Set<String> _selectedProductIds({int? excludingRowIndex}) {
    final ids = <String>{};
    for (var index = 0; index < _rows.length; index++) {
      if (excludingRowIndex != null && index == excludingRowIndex) {
        continue;
      }
      final productId = _rows[index].productId;
      if (productId.isNotEmpty) {
        ids.add(productId);
      }
    }
    return ids;
  }

  bool _canAddMoreRows(List<Product> products) {
    if (products.isEmpty) return false;
    return _rows.length < products.length;
  }

  List<Product> _availableProductsForRow(int rowIndex, List<Product> products) {
    final selectedByOthers = _selectedProductIds(excludingRowIndex: rowIndex);
    final currentId = _rows[rowIndex].productId;

    return products
        .where((product) =>
            product.id == currentId || !selectedByOthers.contains(product.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    final products = widget.productProvider.items;
    if (!_canAddMoreRows(products)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available products are already in the batch list.'),
        ),
      );
      return;
    }

    final selectedIds = _selectedProductIds();
    String defaultProductId = '';
    for (final product in products) {
      if (!selectedIds.contains(product.id)) {
        defaultProductId = product.id;
        break;
      }
    }

    setState(() {
      _rows.add(
        _BatchItemDraft(
          productId: defaultProductId,
          unitType: _unitForProduct(defaultProductId),
        ),
      );
    });
  }

  UnitType _unitForProduct(String productId) {
    if (productId.isEmpty) return UnitType.quantity;

    Product? matchedProduct;
    for (final product in widget.productProvider.items) {
      if (product.id == productId) {
        matchedProduct = product;
        break;
      }
    }

    if (matchedProduct == null) return UnitType.quantity;

    Category? matchedCategory;
    for (final category in widget.categoryProvider.items) {
      if (category.id == matchedProduct.categoryId) {
        matchedCategory = category;
        break;
      }
    }

    return matchedCategory?.defaultUnit ?? UnitType.quantity;
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _saveBatch() async {
    if (widget.productProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create products before adding a batch.')),
      );
      return;
    }

    final items = <BatchItem>[];
    final seenProductIds = <String>{};

    for (final row in _rows) {
      final valueText = row.valueController.text.trim();
      final originalPriceText = row.originalPriceController.text.trim();
      final sellingPriceText = row.sellingPriceController.text.trim();

      if (row.productId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a product for all rows.')),
        );
        return;
      }

      if (!seenProductIds.add(row.productId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duplicate product detected. Each product can only appear once per batch.'),
          ),
        );
        return;
      }

      final value = double.tryParse(valueText);
      final originalPrice = double.tryParse(originalPriceText);
      final sellingPrice = double.tryParse(sellingPriceText);

      if (value == null || originalPrice == null || sellingPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter valid numeric values for value, original price, and selling price.',
            ),
          ),
        );
        return;
      }

      if (row.unitType == UnitType.quantity && value % 1 != 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantity must be a whole number (no decimals).'),
          ),
        );
        return;
      }

      items.add(
        BatchItem(
          productId: row.productId,
          unitType: row.unitType,
          unitValue: value,
          originalPrice: originalPrice,
          sellingPrice: sellingPrice,
        ),
      );
    }

    setState(() => _isSaving = true);
    final error = await widget.stockBatchProvider.createBatch(items);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.productProvider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Stock Batch')),
      body: products.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No products available. Add products first.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Tap "Add Product to Batch" to add items. Unit type follows the selected product category.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _rows.length; index++)
                  _BatchRowCard(
                    index: index,
                    row: _rows[index],
                    products: _availableProductsForRow(index, products),
                    onDelete: _rows.length > 1 ? () => _removeRow(index) : null,
                    onProductChanged: (productId) {
                      final selectedByOthers = _selectedProductIds(excludingRowIndex: index);
                      if (selectedByOthers.contains(productId)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This product is already in the list.'),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _rows[index].productId = productId;
                        _rows[index].unitType = _unitForProduct(productId);

                        if (_rows[index].unitType == UnitType.quantity) {
                          final val = double.tryParse(_rows[index].valueController.text);
                          if (val != null && val % 1 != 0) {
                            _rows[index].valueController.text = val.toInt().toString();
                          }
                        }
                      });
                    },
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _canAddMoreRows(products) ? _addRow : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product to Batch'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isSaving ? null : _saveBatch,
                  child: Text(_isSaving ? 'Saving...' : 'Save Batch'),
                ),
              ],
            ),
    );
  }
}

class _BatchRowCard extends StatelessWidget {
  const _BatchRowCard({
    required this.index,
    required this.row,
    required this.products,
    this.onDelete,
    required this.onProductChanged,
  });

  final int index;
  final _BatchItemDraft row;
  final List<Product> products;
  final VoidCallback? onDelete;
  final ValueChanged<String> onProductChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item ${index + 1}'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    row.unitType.label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 8),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: row.productId.isEmpty ? null : row.productId,
              decoration: const InputDecoration(
                labelText: 'Product',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final product in products)
                  DropdownMenuItem<String>(
                    value: product.id,
                    child: Text(product.name),
                  ),
              ],
              onChanged: (value) {
                final productId = value ?? '';
                onProductChanged(productId);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.valueController,
                    keyboardType: row.unitType == UnitType.quantity
                        ? TextInputType.number
                        : const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: row.unitType == UnitType.quantity
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : [_DecimalTextInputFormatter()],
                    decoration: InputDecoration(
                      labelText: row.unitType == UnitType.kilo ? 'Kilo' : 'Quantity',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.originalPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_DecimalTextInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Capital',
                      prefixText: '₱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.sellingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_DecimalTextInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Sell',
                      prefixText: '₱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final reg = RegExp(r'^\d*\.?\d*$');
    if (reg.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

class _BatchItemDraft {
  _BatchItemDraft({
    required this.productId,
    required this.unitType,
  });

  String productId;
  UnitType unitType;
  final TextEditingController valueController = TextEditingController();
  final TextEditingController originalPriceController = TextEditingController();
  final TextEditingController sellingPriceController = TextEditingController();

  void dispose() {
    valueController.dispose();
    originalPriceController.dispose();
    sellingPriceController.dispose();
  }
}
