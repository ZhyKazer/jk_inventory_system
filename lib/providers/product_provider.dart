import 'package:flutter/foundation.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider(this._repository, this._activityLogProvider);

  final ProductRepositoryInterface _repository;
  final ActivityLogProvider _activityLogProvider;
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

  List<String> parseBulkNames(String rawValue) {
    return rawValue
        .split('\n')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String? validateBulkNames(String rawValue) {
    final names = parseBulkNames(rawValue);
    if (names.isEmpty) {
      return 'At least one product name is required.';
    }

    final existingNames = _items.map((item) => item.name.toLowerCase()).toSet();
    final seenInInput = <String>{};

    for (final name in names) {
      final lowered = name.toLowerCase();

      if (!seenInInput.add(lowered)) {
        return 'Duplicate product in input: "$name".';
      }

      if (existingNames.contains(lowered)) {
        return 'Product name already exists: "$name".';
      }
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
    await _activityLogProvider.log(
      actionType: ActivityActionType.productCreated,
      title: 'Product created',
      description: 'Created product "${product.name}".',
      referenceId: product.id,
    );
    await load();
    return null;
  }

  Future<String?> createMany({
    required List<String> names,
    required String categoryId,
  }) async {
    final categoryError = validateCategory(categoryId);
    if (categoryError != null) return categoryError;
    if (names.isEmpty) return 'At least one product name is required.';

    final normalized = names.map((name) => name.trim()).where((name) => name.isNotEmpty).toList();
    if (normalized.isEmpty) return 'At least one product name is required.';

    final existingNames = _items.map((item) => item.name.toLowerCase()).toSet();
    final seenInInput = <String>{};

    for (final name in normalized) {
      final lowered = name.toLowerCase();
      if (!seenInInput.add(lowered)) {
        return 'Duplicate product in input: "$name".';
      }
      if (existingNames.contains(lowered)) {
        return 'Product name already exists: "$name".';
      }
    }

    final now = DateTime.now();
    for (final name in normalized) {
      final product = Product(
        id: _uuid.v4(),
        categoryId: categoryId,
        name: name,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.create(product);
      await _activityLogProvider.log(
        actionType: ActivityActionType.productCreated,
        title: 'Product created',
        description: 'Created product "${product.name}".',
        referenceId: product.id,
      );
    }

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
    final updated = current.copyWith(
      name: name.trim(),
      categoryId: categoryId,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    await _activityLogProvider.log(
      actionType: ActivityActionType.productUpdated,
      title: 'Product updated',
      description: 'Updated product "${updated.name}".',
      referenceId: updated.id,
    );
    await load();
    return null;
  }

  Future<void> updatePricesFromBatchItems(List<BatchItem> items) async {
    if (items.isEmpty) return;

    final currentById = {for (final product in _items) product.id: product};

    for (final item in items) {
      final current = currentById[item.productId];
      if (current == null) continue;

      final updated = current.copyWith(
        costPrice: item.originalPrice,
        sellingPrice: item.sellingPrice,
        updatedAt: DateTime.now(),
      );

      await _repository.update(updated);
      currentById[item.productId] = updated;
    }

    await load();
  }

  Future<void> delete(String id) async {
    final product = _items.firstWhere((item) => item.id == id);
    await _repository.delete(id);
    await _activityLogProvider.log(
      actionType: ActivityActionType.productDeleted,
      title: 'Product deleted',
      description: 'Deleted product "${product.name}".',
      referenceId: id,
    );
    await load();
  }
}
