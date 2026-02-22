import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider(this._repository);

  final ProductRepository _repository;
  final _uuid = const Uuid();

  List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = _repository.getAll();
    notifyListeners();
  }

  String? validateName(String value, {String? editingId}) {
    final name = value.trim();
    if (name.isEmpty) {
      return 'Product name is required.';
    }

    final exists = _items.any(
      (item) =>
          item.id != editingId && item.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      return 'Product name already exists.';
    }

    return null;
  }

  String? validateCategory(String categoryId) {
    if (categoryId.isEmpty) {
      return 'Category is required.';
    }
    return null;
  }

  Future<String?> create({
    required String name,
    required String categoryId,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) return nameError;

    final categoryError = validateCategory(categoryId);
    if (categoryError != null) return categoryError;

    final now = DateTime.now();
    final product = Product(
      id: _uuid.v4(),
      categoryId: categoryId,
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _repository.create(product);
    await load();
    return null;
  }

  Future<String?> update({
    required String id,
    required String name,
    required String categoryId,
  }) async {
    final nameError = validateName(name, editingId: id);
    if (nameError != null) return nameError;

    final categoryError = validateCategory(categoryId);
    if (categoryError != null) return categoryError;

    final current = _items.firstWhere((item) => item.id == id);
    await _repository.update(
      current.copyWith(
        name: name.trim(),
        categoryId: categoryId,
        updatedAt: DateTime.now(),
      ),
    );
    await load();
    return null;
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await load();
  }
}
