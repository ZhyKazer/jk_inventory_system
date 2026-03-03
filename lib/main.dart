import 'package:flutter/material.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
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

    final repo = InventoryStorage.localRepo();

    _activityLogProvider = ActivityLogProvider(repo.activityLogs);
    _categoryProvider = CategoryProvider(repo.categories, _activityLogProvider);
    _productProvider = ProductProvider(repo.products, _activityLogProvider);
    _stockBatchProvider = StockBatchProvider(repo.stockBatches, _activityLogProvider);
    _outingProvider = OutingProvider(
      repo.outings,
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
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            animationDuration: const Duration(milliseconds: 220),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            animationDuration: const Duration(milliseconds: 220),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            animationDuration: const Duration(milliseconds: 220),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            animationDuration: const Duration(milliseconds: 220),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
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
