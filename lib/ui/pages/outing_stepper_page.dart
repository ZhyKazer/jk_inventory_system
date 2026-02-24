import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';

class OutingStepperPage extends StatefulWidget {
  const OutingStepperPage({
    super.key,
    required this.outingProvider,
    required this.productProvider,
  });

  final OutingProvider outingProvider;
  final ProductProvider productProvider;

  @override
  State<OutingStepperPage> createState() => _OutingStepperPageState();
}

class _OutingStepperPageState extends State<OutingStepperPage> {
  int _currentStep = 0;

  static const List<_WizardStepMeta> _stepMeta = [
    _WizardStepMeta(
      shortLabel: 'Display',
      title: 'Displayed Product Today',
      description: 'Record how many products were placed on display today.',
    ),
    _WizardStepMeta(
      shortLabel: 'Returned',
      title: 'Returned Product Today',
      description: 'Log products that were returned back to inventory today.',
    ),
    _WizardStepMeta(
      shortLabel: 'Discarded',
      title: 'Discarded Product Today',
      description: 'Capture products discarded due to damage or spoilage.',
    ),
    _WizardStepMeta(
      shortLabel: 'Replaced',
      title: 'Replaced Discarded Product Today',
      description: 'Record quantities used to replace discarded products.',
    ),
    _WizardStepMeta(
      shortLabel: 'Review',
      title: 'Review Inputs',
      description: 'Check all entries before final submission.',
    ),
  ];

  UnitType _displayedUnit = UnitType.quantity;
  UnitType _returnedUnit = UnitType.quantity;
  UnitType _discardedUnit = UnitType.quantity;
  UnitType _replacedUnit = UnitType.quantity;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    widget.outingProvider.startDraft();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final error = await widget.outingProvider.submitDraft();
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

  void _goNextStep() {
    setState(() {
      if (_currentStep == 0) {
        _returnedUnit = _displayedUnit;
      }
      if (_currentStep == 2) {
        _replacedUnit = _discardedUnit;
      }
      _currentStep += 1;
    });
  }

  bool _addLine({
    required OutingStepType step,
    required String productId,
    required UnitType unitType,
    required double value,
  }) {
    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a value greater than 0.')),
      );
      return false;
    }

    final error = widget.outingProvider.addLine(
      step,
      OutingLine(productId: productId, unitType: unitType, value: value),
    );

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return false;
    }

    setState(() {});
    return true;
  }

  String _productName(String productId) {
    final product = widget.productProvider.items.where(
      (p) => p.id == productId,
    );
    if (product.isEmpty) return 'Unknown Product';
    return product.first.name;
  }


  bool _canDisplayProduct(Product product, UnitType unitType) {
    return widget.outingProvider.batchStockFor(product.id, unitType) > 0 &&
        widget.outingProvider.availableStock(product.id, unitType) > 0;
  }

  double _sumLines(
    List<OutingLine> lines,
    String productId,
    UnitType unitType,
  ) {
    var total = 0.0;
    for (final line in lines) {
      if (line.productId == productId && line.unitType == unitType) {
        total += line.value;
      }
    }
    return total;
  }

  Widget _buildBalanceBasisCard({
    required String title,
    required List<Product> products,
    required UnitType unitType,
    required List<OutingLine> baseLines,
    required List<OutingLine> consumedLines,
    required String baseLabel,
    required String consumedLabel,
    required String remainingLabel,
  }) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final product in products)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${product.name} (${unitType.label}) • $baseLabel: ${_sumLines(baseLines, product.id, unitType).toStringAsFixed(2)} • $consumedLabel: ${_sumLines(consumedLines, product.id, unitType).toStringAsFixed(2)} • $remainingLabel: ${(_sumLines(baseLines, product.id, unitType) - _sumLines(consumedLines, product.id, unitType)).clamp(0, 999999).toStringAsFixed(2)}',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.productProvider.items;
    if (products.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No products available. Add products first.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!widget.outingProvider.hasAnyBatchStock()) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No stock available from batches yet. Create a stock batch first before starting outings.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Outing Flow')),
      body: AnimatedBuilder(
        animation: widget.outingProvider,
        builder: (context, _) {
          final currentMeta = _stepMeta[_currentStep];
          final isLastStep = _currentStep == _stepMeta.length - 1;
          final stepsLeft = _stepMeta.length - (_currentStep + 1);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _WizardProgressHeader(
                  currentStep: _currentStep,
                  labels: _stepMeta.map((step) => step.shortLabel).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentMeta.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentMeta.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Step ${_currentStep + 1} of ${_stepMeta.length} • $stepsLeft step${stepsLeft == 1 ? '' : 's'} left',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildStepContent(products),
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
                          onPressed: isLastStep
                              ? (_isSubmitting ? null : _submit)
                              : _goNextStep,
                          child: Text(
                            isLastStep
                                ? (_isSubmitting ? 'Submitting...' : 'Submit')
                                : 'Continue',
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

  Widget _buildStepContent(List<Product> products) {
    final displayedProductsForReturned = products
        .where(
          (product) =>
              widget.outingProvider.returnedRemainingFor(
                product.id,
                _returnedUnit,
              ) >
              0,
        )
        .toList();
    final discardedProductsForReplaced = products
        .where(
          (product) =>
              widget.outingProvider.discardedRemainingFor(
                product.id,
                _replacedUnit,
              ) >
              0,
        )
        .toList();
    final discardedStockProducts = products
        .where(
          (product) =>
              widget.outingProvider.batchStockFor(product.id, _discardedUnit) >
                  0 &&
              widget.outingProvider.availableStock(product.id, _discardedUnit) >
                  0,
        )
        .toList();

    switch (_currentStep) {
      case 0:
        final displayableProducts = products
            .where((product) => _canDisplayProduct(product, _displayedUnit))
            .toList();

        return _StepLineEntry(
          products: displayableProducts,
          unitType: _displayedUnit,
          lines: widget.outingProvider.displayedDraft,
          productName: _productName,
          onUnitChanged: (value) => setState(() => _displayedUnit = value),
          onAdd: (productId, value) => _addLine(
            step: OutingStepType.displayed,
            productId: productId,
            unitType: _displayedUnit,
            value: value,
          ),
          onRemoveLine: (index) =>
              widget.outingProvider.removeLine(OutingStepType.displayed, index),
          helperText:
              'Only products with available stock from batches can be displayed.',
          emptyProductsMessage:
              'No products with available batch stock for this unit. Add stock via batches first.',
        );
      case 1:
        return Column(
          children: [
            _buildBalanceBasisCard(
              title: 'Displayed / Returned / Remaining (Sold if not returned)',
              products: displayedProductsForReturned,
              unitType: _returnedUnit,
              baseLines: widget.outingProvider.displayedDraft,
              consumedLines: widget.outingProvider.returnedDraft,
              baseLabel: 'Displayed',
              consumedLabel: 'Returned',
              remainingLabel: 'Remaining',
            ),
            _StepLineEntry(
              products: displayedProductsForReturned,
              unitType: _returnedUnit,
              lines: widget.outingProvider.returnedDraft,
              productName: _productName,
              onUnitChanged: (value) => setState(() => _returnedUnit = value),
              onAdd: (productId, value) => _addLine(
                step: OutingStepType.returned,
                productId: productId,
                unitType: _returnedUnit,
                value: value,
              ),
              onRemoveLine: (index) => widget.outingProvider.removeLine(
                OutingStepType.returned,
                index,
              ),
              helperText:
                  'Returned is based on remaining displayed amount from step 1.',
              emptyProductsMessage:
                  'No displayed amount left to return. Add displayed entries in step 1 first.',
            ),
          ],
        );
      case 2:
        return _StepLineEntry(
          products: discardedStockProducts,
          unitType: _discardedUnit,
          lines: widget.outingProvider.discardedDraft,
          productName: _productName,
          onUnitChanged: (value) => setState(() => _discardedUnit = value),
          onAdd: (productId, value) => _addLine(
            step: OutingStepType.discarded,
            productId: productId,
            unitType: _discardedUnit,
            value: value,
          ),
          onRemoveLine: (index) =>
              widget.outingProvider.removeLine(OutingStepType.discarded, index),
          helperText: 'Discarded comes directly from available stock.',
          emptyProductsMessage:
              'No products currently have available stock to discard.',
        );
      case 3:
        return Column(
          children: [
            _buildBalanceBasisCard(
              title: 'Discarded / Replaced / Remaining Discarded',
              products: discardedProductsForReplaced,
              unitType: _replacedUnit,
              baseLines: widget.outingProvider.discardedDraft,
              consumedLines: widget.outingProvider.replacedDraft,
              baseLabel: 'Discarded',
              consumedLabel: 'Replaced',
              remainingLabel: 'Remaining',
            ),
            _StepLineEntry(
              products: discardedProductsForReplaced,
              unitType: _replacedUnit,
              lines: widget.outingProvider.replacedDraft,
              productName: _productName,
              onUnitChanged: (value) => setState(() => _replacedUnit = value),
              onAdd: (productId, value) => _addLine(
                step: OutingStepType.replaced,
                productId: productId,
                unitType: _replacedUnit,
                value: value,
              ),
              onRemoveLine: (index) => widget.outingProvider.removeLine(
                OutingStepType.replaced,
                index,
              ),
              helperText:
                  'Replacement is based on remaining discarded amount from step 3.',
              emptyProductsMessage:
                  'No discarded amount left. Add discarded items in step 3 first.',
            ),
          ],
        );
      default:
        return _ReviewSection(
          productName: _productName,
          displayed: widget.outingProvider.displayedDraft,
          returned: widget.outingProvider.returnedDraft,
          discarded: widget.outingProvider.discardedDraft,
          replaced: widget.outingProvider.replacedDraft,
        );
    }
  }
}

class _WizardStepMeta {
  const _WizardStepMeta({
    required this.shortLabel,
    required this.title,
    required this.description,
  });

  final String shortLabel;
  final String title;
  final String description;
}

class _WizardProgressHeader extends StatelessWidget {
  const _WizardProgressHeader({
    required this.currentStep,
    required this.labels,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: index == currentStep ? 34 : 28,
                  height: index == currentStep ? 34 : 28,
                  decoration: BoxDecoration(
                    color: index < currentStep
                        ? colorScheme.primary
                        : (index == currentStep
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index == currentStep
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: index == currentStep ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: index < currentStep
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: colorScheme.onPrimary,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: index == currentStep
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: index == currentStep
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: index == currentStep
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1)
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 20),
              color: index < currentStep
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
        ],
      ],
    );
  }
}

class _StepLineEntry extends StatefulWidget {
  const _StepLineEntry({
    required this.products,
    required this.unitType,
    required this.lines,
    required this.productName,
    required this.onUnitChanged,
    required this.onAdd,
    required this.onRemoveLine,
    required this.helperText,
    this.emptyProductsMessage,
  });

  final List<Product> products;
  final UnitType unitType;
  final List<OutingLine> lines;
  final String Function(String) productName;
  final ValueChanged<UnitType> onUnitChanged;
  final bool Function(String productId, double value) onAdd;
  final ValueChanged<int> onRemoveLine;
  final String helperText;
  final String? emptyProductsMessage;

  @override
  State<_StepLineEntry> createState() => _StepLineEntryState();
}

class _StepLineEntryState extends State<_StepLineEntry> {
  final TextEditingController _valueController = TextEditingController();
  String? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _syncSelectedProduct();
  }

  @override
  void didUpdateWidget(covariant _StepLineEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelectedProduct();
  }

  void _syncSelectedProduct() {
    final hasCurrent = widget.products.any(
      (item) => item.id == _selectedProductId,
    );
    if (!hasCurrent) {
      _selectedProductId = widget.products.isNotEmpty
          ? widget.products.first.id
          : null;
    }
  }

  double _parseValue() {
    final text = _valueController.text.trim();
    return double.tryParse(text) ?? 0;
  }

  void _adjustValue(double delta) {
    final nextValue = (_parseValue() + delta).clamp(0, 999999);
    _valueController.text = nextValue % 1 == 0
        ? nextValue.toStringAsFixed(0)
        : nextValue.toStringAsFixed(2);
    _valueController.selection = TextSelection.fromPosition(
      TextPosition(offset: _valueController.text.length),
    );
  }

  void _addProductLine() {
    final productId = _selectedProductId;
    if (productId == null) return;

    final value = _parseValue();
    final added = widget.onAdd(productId, value);
    if (added) {
      _valueController.clear();
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.helperText),
        const SizedBox(height: 8),
        SegmentedButton<UnitType>(
          segments: const [
            ButtonSegment(value: UnitType.quantity, label: Text('Quantity')),
            ButtonSegment(value: UnitType.kilo, label: Text('Kilo')),
          ],
          selected: {widget.unitType},
          onSelectionChanged: (values) => widget.onUnitChanged(values.first),
        ),
        const SizedBox(height: 12),
        if (widget.products.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.emptyProductsMessage ?? 'No products selected yet.',
            ),
          ),
        if (widget.products.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final product in widget.products)
                      DropdownMenuItem<String>(
                        value: product.id,
                        child: Text(product.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedProductId = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _adjustValue(-1),
                      icon: const Icon(Icons.remove),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _valueController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: widget.unitType.label,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () => _adjustValue(1),
                      icon: const Icon(Icons.add),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _selectedProductId == null
                          ? null
                          : _addProductLine,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(76, 48),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (widget.lines.isEmpty)
          const Text('No entries yet.')
        else
          for (var index = 0; index < widget.lines.length; index++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(widget.productName(widget.lines[index].productId)),
                subtitle: Text(widget.lines[index].unitType.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.lines[index].value.toStringAsFixed(2)),
                    IconButton(
                      onPressed: () => widget.onRemoveLine(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.productName,
    required this.displayed,
    required this.returned,
    required this.discarded,
    required this.replaced,
  });

  final String Function(String) productName;
  final List<OutingLine> displayed;
  final List<OutingLine> returned;
  final List<OutingLine> discarded;
  final List<OutingLine> replaced;

  List<OutingLine> _soldLines() {
    final displayedMap = <String, OutingLine>{};
    for (final line in displayed) {
      final key = '${line.productId}_${line.unitType.index}';
      final existing = displayedMap[key];
      if (existing == null) {
        displayedMap[key] = OutingLine(
          productId: line.productId,
          unitType: line.unitType,
          value: line.value,
        );
      } else {
        displayedMap[key] = OutingLine(
          productId: existing.productId,
          unitType: existing.unitType,
          value: existing.value + line.value,
        );
      }
    }

    for (final line in returned) {
      final key = '${line.productId}_${line.unitType.index}';
      final existing = displayedMap[key];
      if (existing == null) continue;
      displayedMap[key] = OutingLine(
        productId: existing.productId,
        unitType: existing.unitType,
        value: existing.value - line.value,
      );
    }

    return displayedMap.values.where((line) => line.value > 0).toList();
  }

  Widget _section(BuildContext context, String title, List<OutingLine> lines) {
    if (lines.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          title: Text(title),
          subtitle: const Text('No entries.'),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${productName(line.productId)} (${line.unitType.label}): ${line.value.toStringAsFixed(2)}',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sold = _soldLines();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, 'Displayed', displayed),
        _section(context, 'Returned', returned),
        _section(context, 'Sold (Displayed - Returned)', sold),
        _section(context, 'Discarded', discarded),
        _section(context, 'Replaced', replaced),
      ],
    );
  }
}
