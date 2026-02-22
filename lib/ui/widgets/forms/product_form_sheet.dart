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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ProductFormSheet(
      provider: provider,
      categories: categories,
      editing: editing,
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
  String _selectedCategoryId = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _selectedCategoryId = widget.editing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final error = widget.editing == null
        ? await widget.provider.create(
            name: _nameController.text,
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

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editing == null ? 'Add Product' : 'Edit Product',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
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
              onChanged: (value) => setState(() => _selectedCategoryId = value ?? ''),
              validator: (value) => widget.provider.validateCategory(value ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
