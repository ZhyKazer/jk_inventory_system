import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/repositories/stock_batch_repository.dart';

class StockBatchProvider extends ChangeNotifier {
  StockBatchProvider(this._repository);

  final StockBatchRepository _repository;
  final _uuid = const Uuid();

  List<StockBatch> _items = [];

  List<StockBatch> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = _repository.getAll();
    notifyListeners();
  }

  String generateBatchName(DateTime now) {
    final datePart = DateFormat('MM_dd_yyyy').format(now);
    final uidPart = _uuid.v4().split('-').first.toUpperCase();
    return 'Batch_$datePart-$uidPart';
  }

  double totalStockFor(String productId, UnitType unitType) {
    var total = 0.0;
    for (final batch in _items) {
      for (final item in batch.items) {
        if (item.productId == productId && item.unitType == unitType) {
          total += item.unitValue;
        }
      }
    }
    return total;
  }

  Future<String?> createBatch(List<BatchItem> items) async {
    if (items.isEmpty) {
      return 'Batch must contain at least one item.';
    }

    for (final item in items) {
      if (item.productId.isEmpty) {
        return 'Product is required for all batch items.';
      }
      if (item.unitValue <= 0) {
        return 'Unit value must be greater than 0.';
      }
      if (item.originalPrice < 0) {
        return 'Original price must be 0 or more.';
      }
      if (item.sellingPrice < 0) {
        return 'Selling price must be 0 or more.';
      }
    }

    final now = DateTime.now();
    final batch = StockBatch(
      id: _uuid.v4(),
      batchName: generateBatchName(now),
      createdAt: now,
      items: items,
    );

    await _repository.create(batch);
    await load();
    return null;
  }
}
