import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';

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
  late final List<TextEditingController> _nameControllers;
  String _selectedCategoryId = '';
  bool _isSaving = false;

  bool get _isCreateMode => widget.editing == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _nameControllers = [TextEditingController()];
    _selectedCategoryId = widget.editing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNameField() {
    setState(() {
      _nameControllers.add(TextEditingController());
    });
  }

  void _removeNameField(int index) {
    if (_nameControllers.length == 1) return;
    setState(() {
      final controller = _nameControllers.removeAt(index);
      controller.dispose();
    });
  }

  List<String> _bulkNames() {
    return _nameControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final error = _isCreateMode
        ? await widget.provider.createMany(
            names: _bulkNames(),
            categoryId: _selectedCategoryId,
          )
        : await widget.provider.update(
            id: widget.editing!.id,
            name: _nameController.text,
            categoryId: _selectedCategoryId,
          );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = (screenSize.height - viewInsets.bottom - 48).clamp(320.0, 620.0);

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
                DropdownButtonFormField<String>(
                  initialValue:
                      _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
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
                Expanded(
                  child: SingleChildScrollView(
                    child: _isCreateMode
                        ? Column(
                            children: [
                              for (var i = 0; i < _nameControllers.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _nameControllers[i],
                                          decoration: InputDecoration(
                                            labelText: 'Product Name ${i + 1}',
                                            border:
                                                const OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            final name = (value ?? '').trim();
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
                                                      (controller) => controller
                                                          .text
                                                          .trim()
                                                          .toLowerCase() ==
                                                      name.toLowerCase(),
                                                    )
                                                    .length;
                                            if (duplicateInInput > 1) {
                                              return 'Duplicate product in form.';
                                            }

                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: _nameControllers.length > 1
                                            ? () => _removeNameField(i)
                                            : null,
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _addNameField,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Another Product'),
                                ),
                              ),
                            ],
                          )
                        : TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => widget.provider.validateName(
                              value ?? '',
                              editingId: widget.editing?.id,
                            ),
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
