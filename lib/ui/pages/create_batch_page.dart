import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';

class CreateBatchPage extends StatefulWidget {
  const CreateBatchPage({
    super.key,
    required this.stockBatchProvider,
    required this.productProvider,
  });

  final StockBatchProvider stockBatchProvider;
  final ProductProvider productProvider;

  @override
  State<CreateBatchPage> createState() => _CreateBatchPageState();
}

class _CreateBatchPageState extends State<CreateBatchPage> {
  final List<_BatchItemDraft> _rows = [];
  bool _isSaving = false;

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
    final defaultProductId = widget.productProvider.items.isNotEmpty
        ? widget.productProvider.items.first.id
        : '';

    setState(() {
      _rows.add(
        _BatchItemDraft(
          productId: defaultProductId,
          unitType: UnitType.quantity,
        ),
      );
    });
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
                  'Add one or more products with supplier/original price, selling price, unit type, and value.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _rows.length; index++)
                  _BatchRowCard(
                    index: index,
                    row: _rows[index],
                    products: products,
                    onDelete: _rows.length > 1 ? () => _removeRow(index) : null,
                    onUnitTypeChanged: (unitType) {
                      setState(() {
                        _rows[index].unitType = unitType;
                        if (unitType == UnitType.quantity) {
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
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product Row'),
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
    required this.onUnitTypeChanged,
  });

  final int index;
  final _BatchItemDraft row;
  final List<Product> products;
  final VoidCallback? onDelete;
  final ValueChanged<UnitType> onUnitTypeChanged;

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
              onChanged: (value) => row.productId = value ?? '',
            ),
            const SizedBox(height: 10),
            SegmentedButton<UnitType>(
              segments: const [
                ButtonSegment(
                  value: UnitType.quantity,
                  label: Text('Quantity'),
                ),
                ButtonSegment(
                  value: UnitType.kilo,
                  label: Text('Kilo'),
                ),
              ],
              selected: {row.unitType},
              onSelectionChanged: (values) {
                onUnitTypeChanged(values.first);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.valueController,
              keyboardType: row.unitType == UnitType.quantity
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: row.unitType == UnitType.quantity
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : [_DecimalTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.originalPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_DecimalTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Original Price (Supplier)',
                prefixText: '₱',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.sellingPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_DecimalTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Selling Price',
                prefixText: '₱',
                border: OutlineInputBorder(),
              ),
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
