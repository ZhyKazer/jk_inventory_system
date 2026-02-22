import 'package:flutter/foundation.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/repositories/outing_repository.dart';
import 'package:jk_inventory_system/services/inventory_stock_calculator.dart';

enum OutingStepType { displayed, returned, discarded, replaced }

class OutingProvider extends ChangeNotifier {
  OutingProvider(
    this._repository,
    this._getBatches,
    this._getProducts,
    this._activityLogProvider,
  );

  final OutingRepository _repository;
  final List<StockBatch> Function() _getBatches;
  final List<Product> Function() _getProducts;
  final ActivityLogProvider _activityLogProvider;
  final InventoryStockCalculator _stockCalculator =
      const InventoryStockCalculator();
  final _uuid = const Uuid();

  List<OutingRecord> _history = [];
  List<OutingLine> _displayedDraft = [];
  List<OutingLine> _returnedDraft = [];
  List<OutingLine> _discardedDraft = [];
  List<OutingLine> _replacedDraft = [];

  List<OutingRecord> get history => List.unmodifiable(_history);
  List<OutingLine> get displayedDraft => List.unmodifiable(_displayedDraft);
  List<OutingLine> get returnedDraft => List.unmodifiable(_returnedDraft);
  List<OutingLine> get discardedDraft => List.unmodifiable(_discardedDraft);
  List<OutingLine> get replacedDraft => List.unmodifiable(_replacedDraft);

  Future<void> load() async {
    _history = _repository.getAll();
    notifyListeners();
  }

  void startDraft() {
    _displayedDraft = [];
    _returnedDraft = [];
    _discardedDraft = [];
    _replacedDraft = [];
    notifyListeners();
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

  double currentStock(String productId, UnitType unitType) {
    return _stockCalculator.currentStock(
      productId: productId,
      unitType: unitType,
      batches: _getBatches(),
      outings: _history,
    );
  }

  double displayedLimit(String productId, UnitType unitType, DateTime date) {
    return _stockCalculator.displayedLimit(
      productId: productId,
      unitType: unitType,
      date: date,
      batches: _getBatches(),
      outings: _history,
    );
  }

  double discardedLimit(String productId, UnitType unitType, DateTime date) {
    return _stockCalculator.discardedLimit(
      productId: productId,
      unitType: unitType,
      date: date,
      batches: _getBatches(),
      outings: _history,
    );
  }

  double _draftNetChange(String productId, UnitType unitType) {
    final displayed = _sumLines(_displayedDraft, productId, unitType);
    final returned = _sumLines(_returnedDraft, productId, unitType);
    final discarded = _sumLines(_discardedDraft, productId, unitType);
    final replaced = _sumLines(_replacedDraft, productId, unitType);
    return -displayed + returned - discarded + replaced;
  }

  double availableStock(String productId, UnitType unitType) {
    return currentStock(productId, unitType) +
        _draftNetChange(productId, unitType);
  }

  double returnedRemainingFor(String productId, UnitType unitType) {
    final displayed = _sumLines(_displayedDraft, productId, unitType);
    final returned = _sumLines(_returnedDraft, productId, unitType);
    final remaining = displayed - returned;
    return remaining > 0 ? remaining : 0;
  }

  double soldFor(String productId, UnitType unitType) {
    final displayed = _sumLines(_displayedDraft, productId, unitType);
    final returned = _sumLines(_returnedDraft, productId, unitType);
    final sold = displayed - returned;
    return sold > 0 ? sold : 0;
  }

  double discardedRemainingFor(String productId, UnitType unitType) {
    final discarded = _sumLines(_discardedDraft, productId, unitType);
    final replaced = _sumLines(_replacedDraft, productId, unitType);
    final remaining = discarded - replaced;
    return remaining > 0 ? remaining : 0;
  }

  double batchStockFor(String productId, UnitType unitType) {
    var batchIn = 0.0;
    for (final batch in _getBatches()) {
      for (final item in batch.items) {
        if (item.productId == productId && item.unitType == unitType) {
          batchIn += item.unitValue;
        }
      }
    }
    return batchIn;
  }

  bool hasAnyBatchStock() {
    for (final batch in _getBatches()) {
      for (final item in batch.items) {
        if (item.unitValue > 0) return true;
      }
    }
    return false;
  }

  bool hasBatchStockForProduct(String productId) {
    for (final batch in _getBatches()) {
      for (final item in batch.items) {
        if (item.productId == productId && item.unitValue > 0) {
          return true;
        }
      }
    }
    return false;
  }

  String? addLine(OutingStepType step, OutingLine line) {
    if (line.productId.isEmpty) return 'Product is required.';
    if (line.value <= 0) return 'Value must be greater than 0.';

    switch (step) {
      case OutingStepType.displayed:
        return _addDisplayed(line);
      case OutingStepType.returned:
        return _addReturned(line);
      case OutingStepType.discarded:
        return _addDiscarded(line);
      case OutingStepType.replaced:
        return _addReplaced(line);
    }
  }

  String? _addDisplayed(OutingLine line) {
    final batchStock = batchStockFor(line.productId, line.unitType);
    if (batchStock <= 0) {
      return 'Displayed requires existing stock from batches.';
    }

    final currentLimit = availableStock(line.productId, line.unitType);
    if (currentLimit <= 0) {
      return 'No available stock to display for this product.';
    }
    if (line.value > currentLimit) {
      return 'Displayed cannot exceed available stock (${currentLimit.toStringAsFixed(2)}).';
    }

    _displayedDraft = [..._displayedDraft, line];
    notifyListeners();
    return null;
  }

  String? _addReturned(OutingLine line) {
    final remaining = returnedRemainingFor(line.productId, line.unitType);
    if (remaining <= 0) {
      return 'No displayed amount left to return for this product.';
    }

    if (line.value > remaining) {
      return 'Returned cannot exceed remaining displayed amount (${remaining.toStringAsFixed(2)}).';
    }

    _returnedDraft = [..._returnedDraft, line];
    notifyListeners();
    return null;
  }

  String? _addDiscarded(OutingLine line) {
    final currentLimit = availableStock(line.productId, line.unitType);
    if (currentLimit <= 0) {
      return 'No available stock to discard for this product.';
    }

    if (line.value > currentLimit) {
      return 'Discarded cannot exceed stock limit (${currentLimit.toStringAsFixed(2)}).';
    }

    _discardedDraft = [..._discardedDraft, line];
    notifyListeners();
    return null;
  }

  String? _addReplaced(OutingLine line) {
    final remaining = discardedRemainingFor(line.productId, line.unitType);

    if (remaining <= 0) {
      return 'No discarded amount left to replace for this product.';
    }
    if (line.value > remaining) {
      return 'Replaced cannot exceed remaining discarded amount (${remaining.toStringAsFixed(2)}).';
    }

    _replacedDraft = [..._replacedDraft, line];
    notifyListeners();
    return null;
  }

  void removeLine(OutingStepType step, int index) {
    switch (step) {
      case OutingStepType.displayed:
        _displayedDraft = [..._displayedDraft]..removeAt(index);
      case OutingStepType.returned:
        _returnedDraft = [..._returnedDraft]..removeAt(index);
      case OutingStepType.discarded:
        _discardedDraft = [..._discardedDraft]..removeAt(index);
      case OutingStepType.replaced:
        _replacedDraft = [..._replacedDraft]..removeAt(index);
    }
    notifyListeners();
  }

  bool get canSubmit => _displayedDraft.isNotEmpty;

  Future<String?> submitDraft() async {
    if (!canSubmit) {
      return 'Displayed products are required before submission.';
    }

    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final record = OutingRecord(
      id: _uuid.v4(),
      date: dateOnly,
      status: OutingStatus.submitted,
      displayedProducts: List<OutingLine>.from(_displayedDraft),
      returnedProducts: List<OutingLine>.from(_returnedDraft),
      discardedProducts: List<OutingLine>.from(_discardedDraft),
      replacedDiscardedProducts: List<OutingLine>.from(_replacedDraft),
      submittedAt: now,
    );

    // Calculate totals
    final products = _getProducts();
    double totalDisplayed = 0;
    double totalReturned = 0;
    double totalDiscarded = 0;
    double totalReplaced = 0;
    double totalSold = 0;
    double totalProfit = 0;
    double totalLost = 0;

    final allLines = [
      ..._displayedDraft,
      ..._returnedDraft,
      ..._discardedDraft,
      ..._replacedDraft,
    ];

    Product? firstProduct;
    for (final line in allLines) {
      final product = products.firstWhere((p) => p.id == line.productId);
      if (firstProduct == null) firstProduct = product;
      final value = line.value;
      if (_displayedDraft.contains(line)) {
        totalDisplayed += value;
      } else if (_returnedDraft.contains(line)) {
        totalReturned += value;
      } else if (_discardedDraft.contains(line)) {
        totalDiscarded += value;
        totalLost += product.costPrice * value;
      } else if (_replacedDraft.contains(line)) {
        totalReplaced += value;
      }
    }

    totalSold = totalDisplayed - totalReturned + totalReplaced;
    if (firstProduct != null) {
      totalProfit =
          totalSold * (firstProduct.sellingPrice - firstProduct.costPrice);
    }

    await _repository.create(record);
    await _activityLogProvider.log(
      actionType: ActivityActionType.outingSubmitted,
      title: 'Outing submitted',
      description:
          'Submitted outing for ${record.date.toIso8601String().split('T').first} with ${record.displayedProducts.length} displayed line(s).',
      referenceId: record.id,
      displayed: totalDisplayed,
      returned: totalReturned,
      discarded: totalDiscarded,
      replaced: totalReplaced,
      sold: totalSold,
      profit: totalProfit,
      lost: totalLost,
    );
    await load();
    startDraft();
    return null;
  }

  double netChangeFor(String productId, UnitType unitType) {
    final displayed = _sumLines(_displayedDraft, productId, unitType);
    final returned = _sumLines(_returnedDraft, productId, unitType);
    final discarded = _sumLines(_discardedDraft, productId, unitType);
    final replaced = _sumLines(_replacedDraft, productId, unitType);

    return -displayed + returned - discarded + replaced;
  }
}
