import 'package:hive_flutter/hive_flutter.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';

class InventoryStorage {
  static const categoriesBoxName = 'categories';
  static const productsBoxName = 'products';
  static const stockBatchesBoxName = 'stock_batches';
  static const outingsBoxName = 'outings';
  static const activityLogsBoxName = 'activity_logs';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ProductAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(StockBatchAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(OutingRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ActivityLogAdapter());
    }

    await Hive.openBox<Category>(categoriesBoxName);
    await Hive.openBox<Product>(productsBoxName);
    await Hive.openBox<StockBatch>(stockBatchesBoxName);
    await Hive.openBox<OutingRecord>(outingsBoxName);
    await Hive.openBox<ActivityLog>(activityLogsBoxName);
  }
}
