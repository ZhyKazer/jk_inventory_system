import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';

class ProductRepository implements ProductRepositoryInterface {
  ProductRepository(this._box);

  final Box<Product> _box;

  List<Product> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> create(Product product) => _box.put(product.id, product);

  Future<void> update(Product product) => _box.put(product.id, product);

  Future<void> delete(String id) => _box.delete(id);
}
