import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/ui/widgets/app_loading.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> showProductFormSheet(
  BuildContext context, {
  required ProductProvider provider,
  required List<Category> categories,
  Product? editing,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: _ProductFormSheet(
        provider: provider,
        categories: categories,
        editing: editing,
      ),
    ),
  );
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({
    required this.provider,
    required this.categories,
    this.editing,
  });

  final ProductProvider provider;
  final List<Category> categories;
  final Product? editing;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _capitalController;
  late final TextEditingController _priceController;
  late final List<TextEditingController> _nameControllers;
  late final List<String?> _imagePaths;
  String? _editingImagePath;
  String _selectedCategoryId = '';
  bool _isCapitalLocked = true;
  bool _isSellingLocked = true;
  bool _isSaving = false;

  bool get _isCreateMode => widget.editing == null;

  bool get _selectedCategoryRequiresImage {
    for (final category in widget.categories) {
      if (category.id == _selectedCategoryId) {
        return category.requireProductImage;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _capitalController = TextEditingController(
      text: widget.editing?.costPrice.toStringAsFixed(2) ?? '',
    );
    _priceController = TextEditingController(
      text: widget.editing?.sellingPrice.toStringAsFixed(2) ?? '',
    );
    _nameControllers = [TextEditingController()];
    _imagePaths = [null];
    _editingImagePath = widget.editing?.imagePath;
    _selectedCategoryId =
        widget.editing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capitalController.dispose();
    _priceController.dispose();
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseOptionalAmount(String rawValue) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _toggleFieldLock({
    required bool isLocked,
    required ValueSetter<bool> onChanged,
    required String fieldLabel,
  }) async {
    if (!isLocked) {
      setState(() => onChanged(true));
      return;
    }

    final shouldUnlock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock Editing'),
        content: Text('Are you sure you want to edit this $fieldLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (!mounted || shouldUnlock != true) return;
    setState(() => onChanged(false));
  }

  void _addNameField() {
    setState(() {
      _nameControllers.add(TextEditingController());
      _imagePaths.add(null);
    });
  }

  void _removeNameField(int index) {
    if (_nameControllers.length == 1) return;
    setState(() {
      final controller = _nameControllers.removeAt(index);
      controller.dispose();
      _imagePaths.removeAt(index);
    });
  }

  List<ProductCreateDraft> _bulkDrafts() {
    final drafts = <ProductCreateDraft>[];
    for (var i = 0; i < _nameControllers.length; i++) {
      final name = _nameControllers[i].text.trim();
      if (name.isEmpty) continue;
      drafts.add(ProductCreateDraft(name: name, imagePath: _imagePaths[i]));
    }
    return drafts;
  }

  Future<void> _pickImage(int index) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (!mounted) return;

    final selectedPath = picked?.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) return;

    final processedPath = await AppLoading.run<String?>(
      context,
      action: () => _processAndStoreImage(selectedPath, index),
      message: 'Processing image...',
    );
    if (!mounted) return;
    if (processedPath == null) return;

    setState(() {
      if (_isCreateMode) {
        _imagePaths[index] = processedPath;
      } else {
        _editingImagePath = processedPath;
      }
    });
  }

  Future<void> _pickMultipleImages() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (!mounted) return;

    final selectedPaths =
        picked?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => path.trim().isNotEmpty)
            .toList() ??
        [];

    if (selectedPaths.isEmpty) {
      return;
    }

    final progressMessage = ValueNotifier<String>(
      'Processing image 1 of ${selectedPaths.length}...',
    );
    final processedPaths = <String>[];

    try {
      await AppLoading.run<void>(
        context,
        action: () async {
          for (var i = 0; i < selectedPaths.length; i++) {
            progressMessage.value =
                'Processing image ${i + 1} of ${selectedPaths.length}...';

            final processedPath = await _processAndStoreImage(
              selectedPaths[i],
              i,
            );
            if (processedPath == null) continue;
            processedPaths.add(processedPath);
          }
        },
        message: 'Processing images...',
        messageListenable: progressMessage,
      );
    } finally {
      progressMessage.dispose();
    }

    if (!mounted) return;

    if (processedPaths.isEmpty || !mounted) {
      return;
    }

    setState(() {
      for (final imagePath in processedPaths) {
        final emptyIndex = _firstCompletelyEmptyRowIndex();
        if (emptyIndex != null) {
          _imagePaths[emptyIndex] = imagePath;
          continue;
        }

        _nameControllers.add(TextEditingController());
        _imagePaths.add(imagePath);
      }
    });
  }

  int? _firstCompletelyEmptyRowIndex() {
    for (var i = 0; i < _nameControllers.length; i++) {
      final name = _nameControllers[i].text.trim();
      final imagePath = _imagePaths[i];
      if (name.isEmpty && (imagePath == null || imagePath.isEmpty)) {
        return i;
      }
    }
    return null;
  }

  Future<String?> _processAndStoreImage(String sourcePath, int index) async {
    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final outputBytes = await compute<Uint8List, Uint8List?>(
        _transformImageToPng,
        sourceBytes,
      );
      if (outputBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to read selected image.')),
          );
        }
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(docsDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          'product_${DateTime.now().microsecondsSinceEpoch}_$index.png';
      final outputPath = p.join(imagesDir.path, fileName);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);
      return outputPath;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process selected image.')),
        );
      }
      return null;
    }
  }

  Future<void> _showLargePreview(String imagePath) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 320,
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
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
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final error = await AppLoading.run<String?>(
      context,
      action: () {
        return _isCreateMode
            ? widget.provider.createMany(
                drafts: _bulkDrafts(),
                categoryId: _selectedCategoryId,
                requireProductImage: _selectedCategoryRequiresImage,
              )
            : widget.provider.update(
                id: widget.editing!.id,
                name: _nameController.text,
                categoryId: _selectedCategoryId,
                imagePath: _editingImagePath,
                costPrice: _parseOptionalAmount(_capitalController.text),
                sellingPrice: _parseOptionalAmount(_priceController.text),
                requireProductImage: _selectedCategoryRequiresImage,
              );
      },
      message: _isCreateMode ? 'Saving products...' : 'Saving product...',
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = (screenSize.height - viewInsets.bottom - 48).clamp(
      320.0,
      620.0,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        width: 520,
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.editing == null ? 'Add Product' : 'Edit Product',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_isCreateMode) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId.isEmpty
                        ? null
                        : _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategoryId = value ?? ''),
                    validator: (value) =>
                        widget.provider.validateCategory(value ?? ''),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: _isCreateMode
                        ? Column(
                            children: [
                              for (var i = 0; i < _nameControllers.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _nameControllers[i],
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Product Name ${i + 1}',
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                              validator: (value) {
                                                final name = (value ?? '')
                                                    .trim();
                                                if (name.isEmpty) {
                                                  return 'Product name is required.';
                                                }

                                                final existingError = widget
                                                    .provider
                                                    .validateName(name);
                                                if (existingError != null) {
                                                  return existingError;
                                                }

                                                final duplicateInInput =
                                                    _nameControllers
                                                        .where(
                                                          (controller) =>
                                                              controller.text
                                                                  .trim()
                                                                  .toLowerCase() ==
                                                              name.toLowerCase(),
                                                        )
                                                        .length;
                                                if (duplicateInInput > 1) {
                                                  return 'Duplicate product in form.';
                                                }

                                                if (_selectedCategoryRequiresImage &&
                                                    (_imagePaths[i] == null ||
                                                        _imagePaths[i]!
                                                            .isEmpty)) {
                                                  return 'Product photo is required.';
                                                }

                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () => _pickImage(i),
                                            onLongPress:
                                                _imagePaths[i] != null &&
                                                    _imagePaths[i]!.isNotEmpty
                                                ? () => _showLargePreview(
                                                    _imagePaths[i]!,
                                                  )
                                                : null,
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(40, 40),
                                              padding: const EdgeInsets.all(8),
                                            ),
                                            child: _imagePaths[i] == null
                                                ? const Icon(
                                                    Icons.add_a_photo_outlined,
                                                  )
                                                : ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    child: SizedBox(
                                                      width: 37,
                                                      height: 37,
                                                      child: Image.file(
                                                        File(_imagePaths[i]!),
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              _,
                                                              _,
                                                            ) => const Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                              size: 18,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            onPressed:
                                                _nameControllers.length > 1
                                                ? () => _removeNameField(i)
                                                : null,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _addNameField,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Another Product'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _pickMultipleImages,
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text('Select Multiple'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _pickImage(0),
                                      onLongPress:
                                          _editingImagePath != null &&
                                              _editingImagePath!.isNotEmpty
                                          ? () => _showLargePreview(
                                                _editingImagePath!,
                                              )
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(120, 120),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      child: _editingImagePath == null ||
                                              _editingImagePath!.isEmpty
                                          ? const Icon(
                                              Icons.add_a_photo_outlined,
                                              size: 30,
                                            )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: SizedBox(
                                                width: 104,
                                                height: 104,
                                                child: Image.file(
                                                  File(_editingImagePath!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, _, _) => const Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        size: 24,
                                                      ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _editingImagePath == null ||
                                              _editingImagePath!.isEmpty
                                          ? 'Photo'
                                          : 'Tap to change, long-press to preview',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_editingImagePath != null &&
                                        _editingImagePath!.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _editingImagePath = null;
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Remove Photo'),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Product Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => widget.provider
                                    .validateName(
                                      value ?? '',
                                      editingId: widget.editing?.id,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _capitalController,
                                      enabled: !_isCapitalLocked,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Capital',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        final normalized = (value ?? '').trim();
                                        if (normalized.isEmpty) return null;
                                        final parsed = double.tryParse(
                                          normalized,
                                        );
                                        if (parsed == null) {
                                          return 'Enter a valid amount.';
                                        }
                                        if (parsed < 0) {
                                          return 'Amount must be 0 or more.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: _isCapitalLocked
                                        ? 'Unlock capital'
                                        : 'Lock capital',
                                    onPressed: () => _toggleFieldLock(
                                      isLocked: _isCapitalLocked,
                                      onChanged: (value) => _isCapitalLocked = value,
                                      fieldLabel: 'capital',
                                    ),
                                    icon: Icon(
                                      _isCapitalLocked
                                          ? Icons.lock_outline
                                          : Icons.lock_open_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _priceController,
                                      enabled: !_isSellingLocked,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Selling Price',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        final normalized = (value ?? '').trim();
                                        if (normalized.isEmpty) return null;
                                        final parsed = double.tryParse(
                                          normalized,
                                        );
                                        if (parsed == null) {
                                          return 'Enter a valid amount.';
                                        }
                                        if (parsed < 0) {
                                          return 'Amount must be 0 or more.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: _isSellingLocked
                                        ? 'Unlock selling price'
                                        : 'Lock selling price',
                                    onPressed: () => _toggleFieldLock(
                                      isLocked: _isSellingLocked,
                                      onChanged: (value) => _isSellingLocked = value,
                                      fieldLabel: 'selling price',
                                    ),
                                    icon: Icon(
                                      _isSellingLocked
                                          ? Icons.lock_outline
                                          : Icons.lock_open_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategoryId.isEmpty
                                    ? null
                                    : _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(),
                                ),
                                items: widget.categories
                                    .map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category.id,
                                        child: Text(category.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(
                                  () => _selectedCategoryId = value ?? '',
                                ),
                                validator: (value) =>
                                    widget.provider.validateCategory(
                                      value ?? '',
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: Text(
                          _isSaving
                              ? 'Saving...'
                              : (_isCreateMode ? 'Save All' : 'Save'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Uint8List? _transformImageToPng(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return null;
  }

  final minSide = math.min(decoded.width, decoded.height);
  final x = (decoded.width - minSide) ~/ 2;
  final y = (decoded.height - minSide) ~/ 2;

  var squared = img.copyCrop(decoded, x: x, y: y, width: minSide, height: minSide);

  if (squared.width > 1024) {
    squared = img.copyResize(
      squared,
      width: 1024,
      height: 1024,
      interpolation: img.Interpolation.average,
    );
  }

  return Uint8List.fromList(img.encodePng(squared, level: 9));
}
