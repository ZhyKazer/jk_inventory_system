import 'package:hive_flutter/hive_flutter.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/product.dart';

class InventoryStorage {
  static const categoriesBoxName = 'categories';
  static const productsBoxName = 'products';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ProductAdapter());
    }

    await Hive.openBox<Category>(categoriesBoxName);
    await Hive.openBox<Product>(productsBoxName);
  }
}
