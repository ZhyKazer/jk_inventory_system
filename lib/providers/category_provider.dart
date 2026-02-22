import 'package:flutter/foundation.dart' hide Category;
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._repository, this._activityLogProvider);

  final CategoryRepository _repository;
  final ActivityLogProvider _activityLogProvider;
  final _uuid = const Uuid();

  List<Category> _items = [];

  List<Category> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = _repository.getAll();
    notifyListeners();
  }

  String? validateName(String value, {String? editingId}) {
    final name = value.trim();
    if (name.isEmpty) {
      return 'Category name is required.';
    }

    final exists = _items.any(
      (item) =>
          item.id != editingId && item.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      return 'Category name already exists.';
    }
    return null;
  }

  Future<String?> create({
    required String name,
    required String colorHex,
  }) async {
    final error = validateName(name);
    if (error != null) return error;

    final now = DateTime.now();
    final category = Category(
      id: _uuid.v4(),
      name: name.trim(),
      colorHex: colorHex,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.create(category);
    await _activityLogProvider.log(
      actionType: ActivityActionType.categoryCreated,
      title: 'Category created',
      description: 'Created category "${category.name}".',
      referenceId: category.id,
    );
    await load();
    return null;
  }

  Future<String?> update({
    required String id,
    required String name,
    required String colorHex,
  }) async {
    final error = validateName(name, editingId: id);
    if (error != null) return error;

    final current = _items.firstWhere((item) => item.id == id);
    final updated = current.copyWith(
      name: name.trim(),
      colorHex: colorHex,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    await _activityLogProvider.log(
      actionType: ActivityActionType.categoryUpdated,
      title: 'Category updated',
      description: 'Updated category "${updated.name}".',
      referenceId: updated.id,
    );
    await load();
    return null;
  }

  bool canDelete(String categoryId, {required bool isUsedByProduct}) {
    return !isUsedByProduct;
  }

  Future<void> delete(String id) async {
    final category = _items.firstWhere((item) => item.id == id);
    await _repository.delete(id);
    await _activityLogProvider.log(
      actionType: ActivityActionType.categoryDeleted,
      title: 'Category deleted',
      description: 'Deleted category "${category.name}".',
      referenceId: id,
    );
    await load();
  }
}
