import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';

class ProductRepository implements ProductRepositoryInterface {
  ProductRepository(this._box);

  final Box<Product> _box;

  List<Product> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (kDebugMode) {
      final withImage = items.where((item) {
        final value = item.imagePath?.trim();
        return value != null && value.isNotEmpty;
      }).length;
      final gsPaths = items.where((item) {
        final value = item.imagePath?.trim();
        return value != null && value.startsWith('gs://');
      }).length;
      final localPaths = withImage - gsPaths;

      debugPrint(
        'Hive ProductRepository.getAll: loaded ${items.length} products, '
        '$withImage with imagePath ($localPaths local, $gsPaths gs://).',
      );

      for (final item in items.take(8)) {
        final imagePath = item.imagePath?.trim();
        debugPrint(
          'Hive product imagePath sample -> id=${item.id}, name=${item.name}, imagePath=${imagePath ?? '<null>'}',
        );
      }
    }

    return items;
  }

  Future<void> create(Product product) => _box.put(product.id, product);

  Future<void> update(Product product) => _box.put(product.id, product);

  Future<void> delete(String id) => _box.delete(id);
}
