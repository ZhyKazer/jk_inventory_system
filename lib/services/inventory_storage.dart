import 'package:hive_flutter/hive_flutter.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/sold_session.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/repositories/category_repository.dart';
import 'package:jk_inventory_system/repositories/product_repository.dart';
import 'package:jk_inventory_system/repositories/stock_batch_repository.dart';
import 'package:jk_inventory_system/repositories/outing_repository.dart';
import 'package:jk_inventory_system/repositories/activity_log_repository.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';
import 'package:jk_inventory_system/repositories/sold_session_repository.dart';

class InventoryStorage {
  static const categoriesBoxName = 'categories';
  static const productsBoxName = 'products';
  static const stockBatchesBoxName = 'stock_batches';
  static const outingsBoxName = 'outings';
  static const activityLogsBoxName = 'activity_logs';
  static const soldSessionsBoxName = 'sold_sessions';
  static const authSessionBoxName = 'auth_session';

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
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SoldSessionAdapter());
    }

    await Hive.openBox<Category>(categoriesBoxName);
    await Hive.openBox<Product>(productsBoxName);
    await Hive.openBox<StockBatch>(stockBatchesBoxName);
    await Hive.openBox<OutingRecord>(outingsBoxName);
    await Hive.openBox<ActivityLog>(activityLogsBoxName);
    await Hive.openBox<SoldSession>(soldSessionsBoxName);
    await Hive.openBox<dynamic>(authSessionBoxName);
  }

  /// Returns a local repository facade backed by the already-opened Hive boxes.
  /// Call `initialize()` first to ensure adapters and boxes are ready.
  static LocalInventoryRepo localRepo() {
    final categoriesBox = Hive.box<Category>(categoriesBoxName);
    final productsBox = Hive.box<Product>(productsBoxName);
    final batchesBox = Hive.box<StockBatch>(stockBatchesBoxName);
    final outingsBox = Hive.box<OutingRecord>(outingsBoxName);
    final activityLogsBox = Hive.box<ActivityLog>(activityLogsBoxName);
    final soldSessionsBox = Hive.box<SoldSession>(soldSessionsBoxName);

    return _LocalInventoryRepoImpl(
      products: ProductRepository(productsBox),
      categories: CategoryRepository(categoriesBox),
      stockBatches: StockBatchRepository(batchesBox),
      outings: OutingRepository(outingsBox),
      activityLogs: ActivityLogRepository(activityLogsBox),
      soldSessions: SoldSessionRepository(soldSessionsBox),
    );
  }
}

class _LocalInventoryRepoImpl implements LocalInventoryRepo {
  _LocalInventoryRepoImpl({
    required this.products,
    required this.categories,
    required this.stockBatches,
    required this.outings,
    required this.activityLogs,
    required this.soldSessions,
  });

  @override
  final ProductRepositoryInterface products;

  @override
  final CategoryRepositoryInterface categories;

  @override
  final StockBatchRepositoryInterface stockBatches;

  @override
  final OutingRepositoryInterface outings;

  @override
  final ActivityLogRepositoryInterface activityLogs;

  @override
  final SoldSessionRepositoryInterface soldSessions;
}
