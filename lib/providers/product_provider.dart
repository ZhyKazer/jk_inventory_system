import 'package:flutter/foundation.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';
import 'package:jk_inventory_system/services/firebase_sync_service.dart';

class ProductCreateDraft {
  ProductCreateDraft({required this.name, this.imagePath});

  final String name;
  final String? imagePath;
}

class ProductProvider extends ChangeNotifier {
  ProductProvider(
    this._repository,
    this._activityLogProvider, {
    FirebaseSyncService? syncService,
  }) : _syncService = syncService ?? FirebaseSyncService();

  final ProductRepositoryInterface _repository;
  final ActivityLogProvider _activityLogProvider;
  final FirebaseSyncService _syncService;
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
    String? imagePath,
    bool requireProductImage = false,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) return nameError;

    final categoryError = validateCategory(categoryId);
    if (categoryError != null) return categoryError;

    final normalizedImagePath = imagePath?.trim();
    if (requireProductImage &&
        (normalizedImagePath == null || normalizedImagePath.isEmpty)) {
      return 'Product image is required.';
    }

    final now = DateTime.now();
    final product = Product(
      id: _uuid.v4(),
      categoryId: categoryId,
      name: name.trim(),
      imagePath: (normalizedImagePath == null || normalizedImagePath.isEmpty)
          ? null
          : normalizedImagePath,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.create(product);
    try {
      await _syncService.upsertProduct(product);
    } catch (error) {
      debugPrint('Firebase product auto-sync (create) failed: $error');
    }
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
    required List<ProductCreateDraft> drafts,
    required String categoryId,
    bool requireProductImage = false,
  }) async {
    final categoryError = validateCategory(categoryId);
    if (categoryError != null) return categoryError;
    if (drafts.isEmpty) return 'At least one product name is required.';

    final normalized = drafts
        .map(
          (draft) => ProductCreateDraft(
            name: draft.name.trim(),
            imagePath: draft.imagePath?.trim(),
          ),
        )
        .where((draft) => draft.name.isNotEmpty)
        .toList();
    if (normalized.isEmpty) return 'At least one product name is required.';

    final existingNames = _items.map((item) => item.name.toLowerCase()).toSet();
    final seenInInput = <String>{};

    for (final draft in normalized) {
      final lowered = draft.name.toLowerCase();
      if (!seenInInput.add(lowered)) {
        return 'Duplicate product in input: "${draft.name}".';
      }
      if (existingNames.contains(lowered)) {
        return 'Product name already exists: "${draft.name}".';
      }

      if (requireProductImage &&
          (draft.imagePath == null || draft.imagePath!.isEmpty)) {
        return 'Product image is required for "${draft.name}".';
      }
    }

    final now = DateTime.now();
    for (final draft in normalized) {
      final product = Product(
        id: _uuid.v4(),
        categoryId: categoryId,
        name: draft.name,
        imagePath: draft.imagePath,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.create(product);
      try {
        await _syncService.upsertProduct(product);
      } catch (error) {
        debugPrint('Firebase product auto-sync (bulk create) failed: $error');
      }
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
    String? imagePath,
    double? costPrice,
    double? sellingPrice,
    bool requireProductImage = false,
  }) async {
    final nameError = validateName(name, editingId: id);
    if (nameError != null) return nameError;

    final categoryError = validateCategory(categoryId);
    if (categoryError != null) return categoryError;

    final normalizedImagePath = imagePath?.trim();
    if (requireProductImage &&
        (normalizedImagePath == null || normalizedImagePath.isEmpty)) {
      return 'Product image is required.';
    }

    final current = _items.firstWhere((item) => item.id == id);
    final updated = current.copyWith(
      name: name.trim(),
      categoryId: categoryId,
      imagePath: (normalizedImagePath == null || normalizedImagePath.isEmpty)
          ? null
          : normalizedImagePath,
      costPrice: costPrice ?? current.costPrice,
      sellingPrice: sellingPrice ?? current.sellingPrice,
      updatedAt: DateTime.now(),
    );
    await _repository.update(updated);
    try {
      await _syncService.upsertProduct(updated);
    } catch (error) {
      debugPrint('Firebase product auto-sync (update) failed: $error');
    }
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
      try {
        await _syncService.upsertProduct(updated);
      } catch (error) {
        debugPrint('Firebase product auto-sync (price update) failed: $error');
      }
      currentById[item.productId] = updated;
    }

    await load();
  }

  Future<void> restorePricesFromBatches(List<StockBatch> batches) async {
    if (batches.isEmpty || _items.isEmpty) return;

    final latestByProduct = <String, ({DateTime createdAt, BatchItem item})>{};

    for (final batch in batches) {
      for (final item in batch.items) {
        if (item.originalPrice <= 0 && item.sellingPrice <= 0) {
          continue;
        }

        final existing = latestByProduct[item.productId];
        if (existing == null || batch.createdAt.isAfter(existing.createdAt)) {
          latestByProduct[item.productId] = (
            createdAt: batch.createdAt,
            item: item,
          );
        }
      }
    }

    if (latestByProduct.isEmpty) return;

    var hasChanges = false;
    for (final product in _items) {
      final latest = latestByProduct[product.id];
      if (latest == null) continue;

      final shouldRestoreCost =
          product.costPrice <= 0 && latest.item.originalPrice > 0;
      final shouldRestoreSelling =
          product.sellingPrice <= 0 && latest.item.sellingPrice > 0;

      if (!shouldRestoreCost && !shouldRestoreSelling) {
        continue;
      }

      final updated = product.copyWith(
        costPrice: shouldRestoreCost
            ? latest.item.originalPrice
            : product.costPrice,
        sellingPrice: shouldRestoreSelling
            ? latest.item.sellingPrice
            : product.sellingPrice,
        updatedAt: DateTime.now(),
      );

      await _repository.update(updated);
      try {
        await _syncService.upsertProduct(updated);
      } catch (error) {
        debugPrint(
          'Firebase product auto-sync (restore prices) failed: $error',
        );
      }
      hasChanges = true;
    }

    if (hasChanges) {
      await load();
    }
  }

  Future<void> delete(String id) async {
    final product = _items.firstWhere((item) => item.id == id);
    await _repository.delete(id);
    try {
      await _syncService.deleteProduct(id);
    } catch (error) {
      debugPrint('Firebase product auto-sync (delete) failed: $error');
    }
    await _activityLogProvider.log(
      actionType: ActivityActionType.productDeleted,
      title: 'Product deleted',
      description: 'Deleted product "${product.name}".',
      referenceId: id,
    );
    await load();
  }
}
