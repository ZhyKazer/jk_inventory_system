import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';

class StockBatchRepository {
  StockBatchRepository(this._box);

  final Box<StockBatch> _box;

  List<StockBatch> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> create(StockBatch batch) => _box.put(batch.id, batch);
}
