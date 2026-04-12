import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/sold_session_provider.dart';
import 'package:jk_inventory_system/services/image_processing_service.dart';
import 'package:jk_inventory_system/ui/widgets/app_loading.dart';

class SoldFlowStepperPage extends StatefulWidget {
  const SoldFlowStepperPage({
    super.key,
    required this.soldSessionProvider,
    required this.productProvider,
    required this.currentUsername,
  });

  final SoldSessionProvider soldSessionProvider;
  final ProductProvider productProvider;
  final String currentUsername;

  @override
  State<SoldFlowStepperPage> createState() => _SoldFlowStepperPageState();
}

class _SoldFlowStepperPageState extends State<SoldFlowStepperPage> {
  final TextEditingController _quantityController = TextEditingController();
  final ImageProcessingService _imageProcessingService =
      ImageProcessingService();

  int _currentStep = 0;
  String? _selectedProductId;
  String? _sharedGcashImagePath;
  String? _sharedShopeeImagePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    widget.soldSessionProvider.startDraft(notify: false);
    if (widget.productProvider.items.isNotEmpty) {
      _selectedProductId = widget.productProvider.items.first.id;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Product? _selectedProduct() {
    final productId = _selectedProductId;
    if (productId == null) return null;
    for (final product in widget.productProvider.items) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  Future<void> _pickAndAttachImage({required bool isGcash}) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (!mounted) return;

    final selectedPath = picked?.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    final processedPath = await AppLoading.run<String?>(
      context,
      action: () => _imageProcessingService.processAndStoreAsPng(
        sourcePath: selectedPath,
        folderName: 'sold_session_images',
        filenamePrefix: isGcash ? 'gcash' : 'sco',
        index: DateTime.now().millisecondsSinceEpoch,
      ),
      message: 'Processing image...',
    );

    if (!mounted || processedPath == null) {
      return;
    }

    setState(() {
      if (isGcash) {
        _sharedGcashImagePath = processedPath;
        widget.soldSessionProvider.setAllGcashImagePath(processedPath);
      } else {
        _sharedShopeeImagePath = processedPath;
        widget.soldSessionProvider.setAllShopeeImagePath(processedPath);
      }
    });
  }

  double _parseQuantity() {
    return double.tryParse(_quantityController.text.trim()) ?? 0;
  }

  void _adjustQuantity(double delta) {
    final nextValue = (_parseQuantity() + delta).clamp(0, 999999);
    _quantityController.text = nextValue % 1 == 0
        ? nextValue.toStringAsFixed(0)
        : nextValue.toStringAsFixed(2);
    _quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: _quantityController.text.length),
    );
  }

  void _addLine() {
    final product = _selectedProduct();
    if (product == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a product first.')));
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    final error = widget.soldSessionProvider.addDraftLine(
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      gcashReceiptImagePath: _sharedGcashImagePath,
      shopeeCheckoutImagePath: _sharedShopeeImagePath,
    );

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _quantityController.clear();
  }

  void _continue() {
    if (_currentStep == 0 && widget.soldSessionProvider.draftLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one sold product first.')),
      );
      return;
    }

    if (_currentStep == 1 && !widget.soldSessionProvider.canContinueToReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attach both shared GCash and shared Shopee images before continuing.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _currentStep += 1;
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final error = await widget.soldSessionProvider.submitDraft(
      username: widget.currentUsername,
    );
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop(true);
  }

  Widget _lineImagePreview(String? path, String emptyLabel) {
    if (path == null || path.trim().isEmpty) {
      return Container(
        width: 86,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          emptyLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 86,
        height: 58,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }

  Future<void> _showLargePreview(String imagePath) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InteractiveViewer(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSoldStep(List<Product> products) {
    final lines = widget.soldSessionProvider.draftLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Sold'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedProductId,
          decoration: const InputDecoration(
            labelText: 'Product',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final product in products)
              DropdownMenuItem(value: product.id, child: Text(product.name)),
          ],
          onChanged: (value) {
            setState(() => _selectedProductId = value);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => _adjustQuantity(-1),
              icon: const Icon(Icons.remove),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _quantityController,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Quantity Sold',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => _adjustQuantity(1),
              icon: const Icon(Icons.add),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: _addLine, child: const Text('Add')),
          ],
        ),
        const SizedBox(height: 12),
        if (lines.isEmpty)
          const Text('No sold products yet.')
        else
          for (var i = 0; i < lines.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${lines[i].productName} • Qty ${lines[i].quantity.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              widget.soldSessionProvider.removeDraftLine(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildProofStep() {
    final lines = widget.soldSessionProvider.draftLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2: Attach shared GCash and Shopee proof images.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: (_sharedGcashImagePath ?? '').trim().isEmpty
                  ? null
                  : () => _showLargePreview(_sharedGcashImagePath!),
              child: _lineImagePreview(_sharedGcashImagePath, 'GCash'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickAndAttachImage(isGcash: true),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Shared GCash Receipt'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: (_sharedShopeeImagePath ?? '').trim().isEmpty
                  ? null
                  : () => _showLargePreview(_sharedShopeeImagePath!),
              child: _lineImagePreview(_sharedShopeeImagePath, 'Shopee'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickAndAttachImage(isGcash: false),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Shared Shopee Checkout Info'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (lines.isNotEmpty)
          Text(
            'These shared images will be used for ${lines.length} sold product line(s).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final lines = widget.soldSessionProvider.draftLines;
    final total = lines.fold<double>(0, (sum, line) => sum + line.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3: Review Product Sold',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text('Session User: ${widget.currentUsername}'),
        Text('Total Quantity: ${total.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        Text(
          'Shared Proof Images',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: (_sharedGcashImagePath ?? '').trim().isEmpty
              ? null
              : () => _showLargePreview(_sharedGcashImagePath!),
          child: Container(
            width: double.infinity,
            height: 190,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: (_sharedGcashImagePath ?? '').trim().isEmpty
                ? Center(
                    child: Text(
                      'GCash',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : Image.file(
                    File(_sharedGcashImagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: (_sharedShopeeImagePath ?? '').trim().isEmpty
              ? null
              : () => _showLargePreview(_sharedShopeeImagePath!),
          child: Container(
            width: double.infinity,
            height: 190,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: (_sharedShopeeImagePath ?? '').trim().isEmpty
                ? Center(
                    child: Text(
                      'Shopee',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : Image.file(
                    File(_sharedShopeeImagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        for (final line in lines)
          Card(
            child: ListTile(
              title: Text(line.productName),
              subtitle: Text('Quantity: ${line.quantity.toStringAsFixed(2)}'),
              trailing: Icon(
                (line.gcashReceiptImagePath ?? '').isNotEmpty &&
                        (line.shopeeCheckoutImagePath ?? '').isNotEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.productProvider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Sold Flow')),
      body: AnimatedBuilder(
        animation: widget.soldSessionProvider,
        builder: (context, _) {
          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No products available. Add products first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(value: 0, label: Text('Product Sold')),
                    ButtonSegment<int>(value: 1, label: Text('GCash + SCO')),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text('Review Product Sold'),
                    ),
                  ],
                  selected: {_currentStep},
                  onSelectionChanged: (_) {},
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _currentStep == 0
                      ? _buildSoldStep(products)
                      : (_currentStep == 1
                            ? _buildProofStep()
                            : _buildReviewStep()),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _currentStep > 0
                              ? () => setState(() => _currentStep -= 1)
                              : null,
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _currentStep < 2
                              ? _continue
                              : (_isSubmitting ? null : _submit),
                          child: Text(
                            _currentStep < 2
                                ? 'Continue'
                                : (_isSubmitting ? 'Submitting...' : 'Submit'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
