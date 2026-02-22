import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/repositories/outing_repository.dart';

enum OutingStepType {
  displayed,
  returned,
  discarded,
  replaced,
}

class OutingProvider extends ChangeNotifier {
  OutingProvider(this._repository, this._getBatches);

  final OutingRepository _repository;
  final List<StockBatch> Function() _getBatches;
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

  String _lineKey(OutingLine line) => '${line.productId}_${line.unitType.index}';

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

  double _sumMap(Map<String, double> map, String productId, UnitType unitType) {
    return map['${productId}_${unitType.index}'] ?? 0;
  }

  Map<String, double> _historicalTotals(List<OutingLine> Function(OutingRecord) pick) {
    final result = <String, double>{};
    for (final record in _history.where((item) => item.status == OutingStatus.submitted)) {
      for (final line in pick(record)) {
        final key = _lineKey(line);
        result[key] = (result[key] ?? 0) + line.value;
      }
    }
    return result;
  }

  double availableStock(String productId, UnitType unitType) {
    var batchIn = 0.0;
    for (final batch in _getBatches()) {
      for (final item in batch.items) {
        if (item.productId == productId && item.unitType == unitType) {
          batchIn += item.unitValue;
        }
      }
    }

    final displayed = _sumMap(
      _historicalTotals((record) => record.displayedProducts),
      productId,
      unitType,
    );
    final returned = _sumMap(
      _historicalTotals((record) => record.returnedProducts),
      productId,
      unitType,
    );
    final discarded = _sumMap(
      _historicalTotals((record) => record.discardedProducts),
      productId,
      unitType,
    );
    final replaced = _sumMap(
      _historicalTotals((record) => record.replacedDiscardedProducts),
      productId,
      unitType,
    );

    return batchIn - displayed + returned - discarded + replaced;
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

    final current = _sumLines(_displayedDraft, line.productId, line.unitType);
    final max = availableStock(line.productId, line.unitType);
    if (max <= 0) {
      return 'No available stock to display for this product.';
    }
    if (current + line.value > max) {
      return 'Displayed cannot exceed available stock (${max.toStringAsFixed(2)}).';
    }

    _displayedDraft = [..._displayedDraft, line];
    notifyListeners();
    return null;
  }

  String? _addReturned(OutingLine line) {
    final displayed = _sumLines(_displayedDraft, line.productId, line.unitType);
    final currentReturned = _sumLines(_returnedDraft, line.productId, line.unitType);

    if (currentReturned + line.value > displayed) {
      return 'Returned cannot exceed displayed amount (${displayed.toStringAsFixed(2)}).';
    }

    _returnedDraft = [..._returnedDraft, line];
    notifyListeners();
    return null;
  }

  String? _addDiscarded(OutingLine line) {
    final available = availableStock(line.productId, line.unitType);
    if (available <= 0) {
      return 'No available stock to discard for this product.';
    }

    final max = available;
    final currentDiscarded = _sumLines(_discardedDraft, line.productId, line.unitType);

    if (currentDiscarded + line.value > max) {
      return 'Discarded cannot exceed stock limit (${max.toStringAsFixed(2)}).';
    }

    _discardedDraft = [..._discardedDraft, line];
    notifyListeners();
    return null;
  }

  String? _addReplaced(OutingLine line) {
    final discarded = _sumLines(_discardedDraft, line.productId, line.unitType);
    final currentReplaced = _sumLines(_replacedDraft, line.productId, line.unitType);

    if (currentReplaced + line.value > discarded) {
      return 'Replaced cannot exceed discarded amount (${discarded.toStringAsFixed(2)}).';
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

    await _repository.create(record);
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
