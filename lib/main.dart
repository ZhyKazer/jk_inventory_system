import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/repositories/activity_log_repository.dart';
import 'package:jk_inventory_system/repositories/category_repository.dart';
import 'package:jk_inventory_system/repositories/outing_repository.dart';
import 'package:jk_inventory_system/repositories/product_repository.dart';
import 'package:jk_inventory_system/repositories/stock_batch_repository.dart';
import 'package:jk_inventory_system/services/inventory_storage.dart';
import 'package:jk_inventory_system/ui/pages/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InventoryStorage.initialize();
  runApp(const InventoryApp());
}

class InventoryApp extends StatefulWidget {
  const InventoryApp({super.key});

  @override
  State<InventoryApp> createState() => _InventoryAppState();
}

class _InventoryAppState extends State<InventoryApp> {
  late final ActivityLogProvider _activityLogProvider;
  late final CategoryProvider _categoryProvider;
  late final ProductProvider _productProvider;
  late final StockBatchProvider _stockBatchProvider;
  late final OutingProvider _outingProvider;

  @override
  void initState() {
    super.initState();

    final categoriesBox = Hive.box<Category>(
      InventoryStorage.categoriesBoxName,
    );
    final productsBox = Hive.box<Product>(InventoryStorage.productsBoxName);
    final batchesBox = Hive.box<StockBatch>(
      InventoryStorage.stockBatchesBoxName,
    );
    final outingsBox = Hive.box<OutingRecord>(InventoryStorage.outingsBoxName);
    final activityLogsBox = Hive.box<ActivityLog>(
      InventoryStorage.activityLogsBoxName,
    );

    _activityLogProvider = ActivityLogProvider(
      ActivityLogRepository(activityLogsBox),
    );
    _categoryProvider = CategoryProvider(
      CategoryRepository(categoriesBox),
      _activityLogProvider,
    );
    _productProvider = ProductProvider(
      ProductRepository(productsBox),
      _activityLogProvider,
    );
    _stockBatchProvider = StockBatchProvider(
      StockBatchRepository(batchesBox),
      _activityLogProvider,
    );
    _outingProvider = OutingProvider(
      OutingRepository(outingsBox),
      () => _stockBatchProvider.items,
      () => _productProvider.items,
      _activityLogProvider,
    );

    _activityLogProvider.load();
    _categoryProvider.load();
    _productProvider.load();
    _stockBatchProvider.load();
    _outingProvider.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JK Inventory System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomeShell(
        categoryProvider: _categoryProvider,
        productProvider: _productProvider,
        stockBatchProvider: _stockBatchProvider,
        outingProvider: _outingProvider,
        activityLogProvider: _activityLogProvider,
      ),
    );
  }
}
