import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/repositories/category_repository.dart';
import 'package:jk_inventory_system/repositories/product_repository.dart';
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
  late final CategoryProvider _categoryProvider;
  late final ProductProvider _productProvider;

  @override
  void initState() {
    super.initState();

    final categoriesBox = Hive.box<Category>(InventoryStorage.categoriesBoxName);
    final productsBox = Hive.box<Product>(InventoryStorage.productsBoxName);

    _categoryProvider = CategoryProvider(CategoryRepository(categoriesBox));
    _productProvider = ProductProvider(ProductRepository(productsBox));

    _categoryProvider.load();
    _productProvider.load();
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
      ),
    );
  }
}
