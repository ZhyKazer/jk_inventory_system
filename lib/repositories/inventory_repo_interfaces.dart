import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/sold_session.dart';

abstract class ProductRepositoryInterface {
  List<Product> getAll();
  Future<void> create(Product product);
  Future<void> update(Product product);
  Future<void> delete(String id);
}

abstract class CategoryRepositoryInterface {
  List<Category> getAll();
  Future<void> create(Category category);
  Future<void> update(Category category);
  Future<void> delete(String id);
}

abstract class StockBatchRepositoryInterface {
  List<StockBatch> getAll();
  Future<void> create(StockBatch batch);
}

abstract class OutingRepositoryInterface {
  List<OutingRecord> getAll();
  Future<void> create(OutingRecord record);
}

abstract class ActivityLogRepositoryInterface {
  List<ActivityLog> getAll();
  Future<void> create(ActivityLog activityLog);
}

abstract class SoldSessionRepositoryInterface {
  List<SoldSession> getAll();
  Future<void> create(SoldSession session);
  Future<void> update(SoldSession session);
}

/// High-level local inventory facade to allow swapping implementations later.
abstract class LocalInventoryRepo {
  ProductRepositoryInterface get products;
  CategoryRepositoryInterface get categories;
  StockBatchRepositoryInterface get stockBatches;
  OutingRepositoryInterface get outings;
  ActivityLogRepositoryInterface get activityLogs;
  SoldSessionRepositoryInterface get soldSessions;
}

/// Cloud counterpart placeholder for future Firebase implementation.
abstract class CloudInventoryRepo {
  // TODO: define cloud methods mirroring LocalInventoryRepo for sync.
}
