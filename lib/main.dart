import 'package:flutter/material.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/services/inventory_storage.dart';
import 'package:jk_inventory_system/ui/pages/home_shell.dart';
import 'package:jk_inventory_system/ui/theme/app_theme_option.dart';

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
  AppThemeOption _selectedTheme = AppThemeOption.dark;
  Color _customThemeColor = Colors.deepPurple;

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

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _activityLogProvider.load();
    await _categoryProvider.load();
    await _productProvider.load();
    await _stockBatchProvider.load();
    await _productProvider.restorePricesFromBatches(_stockBatchProvider.items);
    await _outingProvider.load();
  }

  void _setTheme(AppThemeOption theme) {
    setState(() {
      _selectedTheme = theme;
    });
  }

  void _setCustomThemeColor(Color color) {
    setState(() {
      _customThemeColor = color;
      _selectedTheme = AppThemeOption.custom;
    });
  }

  ThemeData _buildThemeData({
    required Color seedColor,
    required Brightness brightness,
  }) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness),
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
    );
  }

  ThemeData _themeFromSelection() {
    return switch (_selectedTheme) {
      AppThemeOption.light =>
        _buildThemeData(seedColor: Colors.indigo, brightness: Brightness.light),
      AppThemeOption.dark =>
        _buildThemeData(seedColor: Colors.indigo, brightness: Brightness.dark),
      AppThemeOption.blue =>
        _buildThemeData(seedColor: Colors.blue, brightness: Brightness.light),
      AppThemeOption.green =>
        _buildThemeData(seedColor: Colors.green, brightness: Brightness.light),
      AppThemeOption.custom =>
        _buildThemeData(seedColor: _customThemeColor, brightness: Brightness.light),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bnm',
      debugShowCheckedModeBanner: false,
      theme: _themeFromSelection(),
      home: HomeShell(
        categoryProvider: _categoryProvider,
        productProvider: _productProvider,
        stockBatchProvider: _stockBatchProvider,
        outingProvider: _outingProvider,
        activityLogProvider: _activityLogProvider,
        selectedTheme: _selectedTheme,
        onThemeSelected: _setTheme,
        selectedCustomThemeColor: _customThemeColor,
        onCustomThemeColorSelected: _setCustomThemeColor,
      ),
    );
  }
}
