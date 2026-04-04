import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';
import 'package:jk_inventory_system/services/inventory_stock_calculator.dart';

enum OutingStepType { displayed, returned, discarded, replaced }

class OutingProductCalculation {
  OutingProductCalculation({
    required this.productId,
    required this.productName,
    required this.displayed,
    required this.returned,
    required this.sold,
    required this.currentCapital,
    required this.currentSelling,
    required this.revenue,
    required this.capitalCost,
    required this.approxProfit,
  });

  final String productId;
  final String productName;
  final double displayed;
  final double returned;
  final double sold;
  final double currentCapital;
  final double currentSelling;
  final double revenue;
  final double capitalCost;
  final double approxProfit;
}

class OutingCalculationSummary {
  OutingCalculationSummary({
    required this.totalDisplayed,
    required this.totalReturned,
    required this.totalDiscarded,
    required this.totalReplaced,
    required this.totalSold,
    required this.totalRevenue,
    required this.totalCapital,
    required this.approximateProfit,
    required this.totalLost,
    required this.perProduct,
  });

  final double totalDisplayed;
  final double totalReturned;
  final double totalDiscarded;
  final double totalReplaced;
  final double totalSold;
  final double totalRevenue;
  final double totalCapital;
  final double approximateProfit;
  final double totalLost;
  final List<OutingProductCalculation> perProduct;
}

class OutingProvider extends ChangeNotifier {
  OutingProvider(
    this._repository,
    this._getBatches,
    this._getProducts,
    this._activityLogProvider,
  );

  final OutingRepositoryInterface _repository;
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

  void startDraft({bool notify = true}) {
    final hadDraftData =
        _displayedDraft.isNotEmpty ||
        _returnedDraft.isNotEmpty ||
        _discardedDraft.isNotEmpty ||
        _replacedDraft.isNotEmpty;

    _displayedDraft = [];
    _returnedDraft = [];
    _discardedDraft = [];
    _replacedDraft = [];

    if (notify && hadDraftData) {
      notifyListeners();
    }
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

  Map<String, double> _sumByProduct(List<OutingLine> lines) {
    final totals = <String, double>{};
    for (final line in lines) {
      totals.update(
        line.productId,
        (value) => value + line.value,
        ifAbsent: () => line.value,
      );
    }
    return totals;
  }

  double _soldRevenueForProduct({
    required String productId,
    required double returned,
    required double defaultSellingPrice,
  }) {
    var remainingReturned = returned;
    var revenue = 0.0;

    for (final line in _displayedDraft) {
      if (line.productId != productId) {
        continue;
      }

      final displayedValue = line.value;
      if (displayedValue <= 0) {
        continue;
      }

      final returnedFromLine = remainingReturned <= 0
          ? 0.0
          : (remainingReturned >= displayedValue
                ? displayedValue
                : remainingReturned);
      remainingReturned -= returnedFromLine;

      final soldFromLine = displayedValue - returnedFromLine;
      if (soldFromLine <= 0) {
        continue;
      }

      final sellingPrice = line.sellingPriceOverride ?? defaultSellingPrice;
      revenue += soldFromLine * sellingPrice;
    }

    return revenue;
  }

  OutingCalculationSummary calculateDraftSummary() {
    final products = _getProducts();
    final productsById = {for (final product in products) product.id: product};

    final displayedByProduct = _sumByProduct(_displayedDraft);
    final returnedByProduct = _sumByProduct(_returnedDraft);
    final discardedByProduct = _sumByProduct(_discardedDraft);
    final replacedByProduct = _sumByProduct(_replacedDraft);

    final allProductIds = <String>{
      ...displayedByProduct.keys,
      ...returnedByProduct.keys,
      ...discardedByProduct.keys,
      ...replacedByProduct.keys,
    };

    var totalDisplayed = 0.0;
    var totalReturned = 0.0;
    var totalDiscarded = 0.0;
    var totalReplaced = 0.0;
    var totalSold = 0.0;
    var totalRevenue = 0.0;
    var totalCapital = 0.0;
    var totalLost = 0.0;
    final perProduct = <OutingProductCalculation>[];

    for (final productId in allProductIds) {
      final product = productsById[productId];
      final displayed = displayedByProduct[productId] ?? 0.0;
      final returned = returnedByProduct[productId] ?? 0.0;
      final discarded = discardedByProduct[productId] ?? 0.0;
      final replaced = replacedByProduct[productId] ?? 0.0;
      final sold = displayed - returned;
      final safeSold = sold > 0 ? sold : 0.0;

      final capital = product?.costPrice ?? 0.0;
      final selling = product?.sellingPrice ?? 0.0;
      final revenue = _soldRevenueForProduct(
        productId: productId,
        returned: returned,
        defaultSellingPrice: selling,
      );
      final capitalCost = safeSold * capital;
      final approxProfit = revenue - capitalCost;
      final lost = discarded * capital;
      final effectiveSelling = safeSold > 0 ? revenue / safeSold : selling;

      totalDisplayed += displayed;
      totalReturned += returned;
      totalDiscarded += discarded;
      totalReplaced += replaced;
      totalSold += safeSold;
      totalRevenue += revenue;
      totalCapital += capitalCost;
      totalLost += lost;

      if (displayed > 0 || returned > 0 || safeSold > 0) {
        perProduct.add(
          OutingProductCalculation(
            productId: productId,
            productName: product?.name ?? 'Unknown Product',
            displayed: displayed,
            returned: returned,
            sold: safeSold,
            currentCapital: capital,
            currentSelling: effectiveSelling,
            revenue: revenue,
            capitalCost: capitalCost,
            approxProfit: approxProfit,
          ),
        );
      }
    }

    perProduct.sort((a, b) => a.productName.compareTo(b.productName));

    return OutingCalculationSummary(
      totalDisplayed: totalDisplayed,
      totalReturned: totalReturned,
      totalDiscarded: totalDiscarded,
      totalReplaced: totalReplaced,
      totalSold: totalSold,
      totalRevenue: totalRevenue,
      totalCapital: totalCapital,
      approximateProfit: totalRevenue - totalCapital,
      totalLost: totalLost,
      perProduct: perProduct,
    );
  }

  Future<String?> submitDraft() async {
    if (!canSubmit) {
      return 'Displayed products are required before submission.';
    }

    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final summary = calculateDraftSummary();
    final record = OutingRecord(
      id: _uuid.v4(),
      date: dateOnly,
      status: OutingStatus.submitted,
      displayedProducts: List<OutingLine>.from(_displayedDraft),
      returnedProducts: List<OutingLine>.from(_returnedDraft),
      discardedProducts: List<OutingLine>.from(_discardedDraft),
      replacedDiscardedProducts: List<OutingLine>.from(_replacedDraft),
      submittedAt: now,
      totalDisplayed: summary.totalDisplayed,
      totalReturned: summary.totalReturned,
      totalDiscarded: summary.totalDiscarded,
      totalReplaced: summary.totalReplaced,
      totalSold: summary.totalSold,
      totalRevenue: summary.totalRevenue,
      totalCapital: summary.totalCapital,
      approximateProfit: summary.approximateProfit,
    );

    await _repository.create(record);

    // Build product details JSON for activity log
    final productDetailsJson = jsonEncode(
      summary.perProduct
          .map(
            (calc) => {
              'productId': calc.productId,
              'productName': calc.productName,
              'displayed': calc.displayed,
              'returned': calc.returned,
              'sold': calc.sold,
              'sellingPrice': calc.currentSelling,
              'costPrice': calc.currentCapital,
              'revenue': calc.revenue,
              'capital': calc.capitalCost,
              'profit': calc.approxProfit,
            },
          )
          .toList(),
    );

    await _activityLogProvider.log(
      actionType: ActivityActionType.outingSubmitted,
      title: 'Outing submitted',
      description:
          'Submitted outing for ${record.date.toIso8601String().split('T').first} with ${record.displayedProducts.length} displayed line(s).',
      referenceId: record.id,
      displayed: summary.totalDisplayed,
      returned: summary.totalReturned,
      discarded: summary.totalDiscarded,
      replaced: summary.totalReplaced,
      sold: summary.totalSold,
      profit: summary.approximateProfit,
      lost: summary.totalLost,
      productDetails: productDetailsJson,
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
