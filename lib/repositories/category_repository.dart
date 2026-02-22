import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/category.dart';

class CategoryRepository {
  CategoryRepository(this._box);

  final Box<Category> _box;

  List<Category> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> create(Category category) => _box.put(category.id, category);

  Future<void> update(Category category) => _box.put(category.id, category);

  Future<void> delete(String id) => _box.delete(id);
}
