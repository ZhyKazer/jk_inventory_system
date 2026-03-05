import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' show ColorPicker;
import 'dart:math';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/ui/utils/color_utils.dart' as color_utils;

Future<void> showCategoryFormSheet(
  BuildContext context, {
  required CategoryProvider provider,
  Category? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _CategoryFormSheet(provider: provider, editing: editing),
  );
}

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({required this.provider, this.editing});

  final CategoryProvider provider;
  final Category? editing;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Color _selectedColor;
  late bool _requireProductImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _selectedColor = widget.editing != null
        ? color_utils.colorFromHex(widget.editing!.colorHex)
        : Color(0xFF000000 | Random().nextInt(0xFFFFFF));
    _requireProductImage = widget.editing?.requireProductImage ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final name = _nameController.text;
    final colorHex = color_utils.colorToHex(_selectedColor);

    final error = widget.editing == null
        ? await widget.provider.create(
            name: name,
            colorHex: colorHex,
            requireProductImage: _requireProductImage,
          )
        : await widget.provider.update(
            id: widget.editing!.id,
            name: name,
            colorHex: colorHex,
            requireProductImage: _requireProductImage,
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
              widget.editing == null ? 'Add Category' : 'Edit Category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require Product Image'),
              subtitle: Text(_requireProductImage ? 'On' : 'Off'),
              value: _requireProductImage,
              onChanged: (value) =>
                  setState(() => _requireProductImage = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => widget.provider.validateName(
                value ?? '',
                editingId: widget.editing?.id,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Color'),
            const SizedBox(height: 8),
            ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (value) => setState(() => _selectedColor = value),
              enableAlpha: true,
              labelTypes: const [],
              portraitOnly: true,
              pickerAreaHeightPercent: 0.4,
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
