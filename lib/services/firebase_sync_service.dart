import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/services/inventory_storage.dart';

class FirebaseSyncSummary {
  const FirebaseSyncSummary({
    required this.categories,
    required this.products,
    required this.stockBatches,
    required this.outings,
    required this.activities,
  });

  final int categories;
  final int products;
  final int stockBatches;
  final int outings;
  final int activities;

  int get total => categories + products + stockBatches + outings + activities;
}

class FirebaseSyncService {
  FirebaseSyncService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: 'gs://bnm-inventory.firebasestorage.app',
          );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<FirebaseSyncSummary> replaceLocalWithFirestore({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Fetching categories from Firebase...');
    final categoriesSnapshot = await _firestore.collection('categories').get();

    onProgress?.call('Fetching products from Firebase...');
    final productsSnapshot = await _firestore.collection('products').get();

    onProgress?.call('Fetching stock batches from Firebase...');
    final stockBatchesSnapshot = await _firestore
        .collection('stockBatches')
        .get();

    onProgress?.call('Fetching outings from Firebase...');
    final outingsSnapshot = await _firestore.collection('outings').get();

    onProgress?.call('Fetching activities from Firebase...');
    final activitiesSnapshot = await _firestore.collection('activities').get();

    final categories = categoriesSnapshot.docs
        .map((doc) => _categoryFromMap(doc.data()))
        .whereType<Category>()
        .toList(growable: false);
    final products = productsSnapshot.docs
        .map((doc) => _productFromMap(doc.data()))
        .whereType<Product>()
        .toList(growable: false);
    final stockBatches = stockBatchesSnapshot.docs
        .map((doc) => _stockBatchFromMap(doc.data()))
        .whereType<StockBatch>()
        .toList(growable: false);
    final outings = outingsSnapshot.docs
        .map((doc) => _outingFromMap(doc.data()))
        .whereType<OutingRecord>()
        .toList(growable: false);
    final activities = activitiesSnapshot.docs
        .map((doc) => _activityFromMap(doc.data()))
        .whereType<ActivityLog>()
        .toList(growable: false);

    onProgress?.call('Replacing local backup cache...');
    final categoriesBox = Hive.box<Category>(
      InventoryStorage.categoriesBoxName,
    );
    final productsBox = Hive.box<Product>(InventoryStorage.productsBoxName);
    final stockBatchesBox = Hive.box<StockBatch>(
      InventoryStorage.stockBatchesBoxName,
    );
    final outingsBox = Hive.box<OutingRecord>(InventoryStorage.outingsBoxName);
    final activitiesBox = Hive.box<ActivityLog>(
      InventoryStorage.activityLogsBoxName,
    );

    await categoriesBox.clear();
    await productsBox.clear();
    await stockBatchesBox.clear();
    await outingsBox.clear();
    await activitiesBox.clear();

    await categoriesBox.putAll({for (final item in categories) item.id: item});
    await productsBox.putAll({for (final item in products) item.id: item});
    await stockBatchesBox.putAll({
      for (final item in stockBatches) item.id: item,
    });
    await outingsBox.putAll({for (final item in outings) item.id: item});
    await activitiesBox.putAll({for (final item in activities) item.id: item});

    return FirebaseSyncSummary(
      categories: categories.length,
      products: products.length,
      stockBatches: stockBatches.length,
      outings: outings.length,
      activities: activities.length,
    );
  }

  Future<void> upsertCategory(Category category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .set(_categoryToMap(category), SetOptions(merge: true));
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }

  Future<void> upsertProduct(Product product) async {
    final data = await _productToMap(product);
    await _firestore
        .collection('products')
        .doc(product.id)
        .set(data, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  Future<void> upsertStockBatch(StockBatch batch) async {
    await _firestore
        .collection('stockBatches')
        .doc(batch.id)
        .set(_stockBatchToMap(batch), SetOptions(merge: true));
  }

  Future<void> upsertOuting(OutingRecord outing) async {
    await _firestore
        .collection('outings')
        .doc(outing.id)
        .set(_outingToMap(outing), SetOptions(merge: true));
  }

  Future<void> upsertActivity(ActivityLog activity) async {
    await _firestore
        .collection('activities')
        .doc(activity.id)
        .set(_activityToMap(activity), SetOptions(merge: true));
  }

  Future<FirebaseSyncSummary> syncLocalToFirestore({
    void Function(String message)? onProgress,
    bool overwriteRemote = false,
  }) async {
    final categories = Hive.box<Category>(
      InventoryStorage.categoriesBoxName,
    ).values.toList(growable: false);
    final products = Hive.box<Product>(
      InventoryStorage.productsBoxName,
    ).values.toList(growable: false);
    final stockBatches = Hive.box<StockBatch>(
      InventoryStorage.stockBatchesBoxName,
    ).values.toList(growable: false);
    final outings = Hive.box<OutingRecord>(
      InventoryStorage.outingsBoxName,
    ).values.toList(growable: false);
    final activities = Hive.box<ActivityLog>(
      InventoryStorage.activityLogsBoxName,
    ).values.toList(growable: false);

    final writes = <_SyncWrite>[];

    onProgress?.call('Preparing categories...');
    for (final category in categories) {
      writes.add(
        _SyncWrite(
          ref: _firestore.collection('categories').doc(category.id),
          data: _categoryToMap(category),
        ),
      );
    }

    onProgress?.call('Preparing products...');
    for (final product in products) {
      final productMap = await _productToMap(
        product,
        onProgress: (message) => onProgress?.call(message),
      );
      writes.add(
        _SyncWrite(
          ref: _firestore.collection('products').doc(product.id),
          data: productMap,
        ),
      );
    }

    onProgress?.call('Preparing stock batches...');
    for (final batch in stockBatches) {
      writes.add(
        _SyncWrite(
          ref: _firestore.collection('stockBatches').doc(batch.id),
          data: _stockBatchToMap(batch),
        ),
      );
    }

    onProgress?.call('Preparing outings...');
    for (final outing in outings) {
      writes.add(
        _SyncWrite(
          ref: _firestore.collection('outings').doc(outing.id),
          data: _outingToMap(outing),
        ),
      );
    }

    onProgress?.call('Preparing activity logs...');
    for (final activity in activities) {
      writes.add(
        _SyncWrite(
          ref: _firestore.collection('activities').doc(activity.id),
          data: _activityToMap(activity),
        ),
      );
    }

    onProgress?.call('Syncing ${writes.length} record(s) to Firebase...');
    await _commitInChunks(writes, onProgress: onProgress);

    if (overwriteRemote) {
      onProgress?.call(
        'Removing remote records not present in local backup...',
      );
      await _deleteMissingRemoteDocuments(
        collectionPath: 'categories',
        localIds: categories.map((item) => item.id).toSet(),
      );
      await _deleteMissingRemoteDocuments(
        collectionPath: 'products',
        localIds: products.map((item) => item.id).toSet(),
      );
      await _deleteMissingRemoteDocuments(
        collectionPath: 'stockBatches',
        localIds: stockBatches.map((item) => item.id).toSet(),
      );
      await _deleteMissingRemoteDocuments(
        collectionPath: 'outings',
        localIds: outings.map((item) => item.id).toSet(),
      );
      await _deleteMissingRemoteDocuments(
        collectionPath: 'activities',
        localIds: activities.map((item) => item.id).toSet(),
      );
    }

    return FirebaseSyncSummary(
      categories: categories.length,
      products: products.length,
      stockBatches: stockBatches.length,
      outings: outings.length,
      activities: activities.length,
    );
  }

  Future<void> _commitInChunks(
    List<_SyncWrite> writes, {
    void Function(String message)? onProgress,
  }) async {
    const chunkSize = 400;
    var offset = 0;

    while (offset < writes.length) {
      final end = (offset + chunkSize < writes.length)
          ? offset + chunkSize
          : writes.length;
      final chunk = writes.sublist(offset, end);

      final batch = _firestore.batch();
      for (final write in chunk) {
        batch.set(write.ref, write.data, SetOptions(merge: true));
      }

      await batch.commit();
      onProgress?.call('Synced $end of ${writes.length}...');
      offset = end;
    }
  }

  Future<void> _deleteMissingRemoteDocuments({
    required String collectionPath,
    required Set<String> localIds,
  }) async {
    final snapshot = await _firestore.collection(collectionPath).get();
    final missingIds = snapshot.docs
        .map((doc) => doc.id)
        .where((id) => !localIds.contains(id))
        .toList(growable: false);

    if (missingIds.isEmpty) {
      return;
    }

    const chunkSize = 400;
    var offset = 0;
    while (offset < missingIds.length) {
      final end = (offset + chunkSize < missingIds.length)
          ? offset + chunkSize
          : missingIds.length;
      final chunk = missingIds.sublist(offset, end);
      final batch = _firestore.batch();

      for (final id in chunk) {
        batch.delete(_firestore.collection(collectionPath).doc(id));
      }

      await batch.commit();
      offset = end;
    }
  }

  Map<String, dynamic> _categoryToMap(Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'colorHex': category.colorHex,
      'requireProductImage': category.requireProductImage,
      'allowFlexibleSellingPrice': category.allowFlexibleSellingPrice,
      'createdAt': category.createdAt,
      'updatedAt': category.updatedAt,
    };
  }

  Future<Map<String, dynamic>> _productToMap(
    Product product, {
    void Function(String message)? onProgress,
  }) async {
    final imagePath = await _resolveProductImagePath(
      productId: product.id,
      currentPath: product.imagePath,
      onProgress: onProgress,
    );

    return {
      'id': product.id,
      'categoryId': product.categoryId,
      'name': product.name,
      'imagePath': imagePath,
      'costPrice': product.costPrice,
      'sellingPrice': product.sellingPrice,
      'createdAt': product.createdAt,
      'updatedAt': product.updatedAt,
    };
  }

  Future<String?> _resolveProductImagePath({
    required String productId,
    required String? currentPath,
    void Function(String message)? onProgress,
  }) async {
    final normalized = currentPath?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized.startsWith('gs://')) {
      return normalized;
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    final imageFile = File(normalized);
    if (!imageFile.existsSync()) {
      return normalized;
    }

    onProgress?.call('Uploading image for product $productId...');

    final namePart = imageFile.uri.pathSegments.isNotEmpty
        ? imageFile.uri.pathSegments.last
        : 'product_image.jpg';
    final objectPath = 'product_images/$productId/$namePart';
    final ref = _storage.ref(objectPath);
    await ref.putFile(imageFile);

    return 'gs://${_storage.bucket}/$objectPath';
  }

  Map<String, dynamic> _stockBatchToMap(StockBatch batch) {
    return {
      'id': batch.id,
      'batchName': batch.batchName,
      'createdAt': batch.createdAt,
      'items': [
        for (final item in batch.items)
          {
            'productId': item.productId,
            'unitType': item.unitType.name,
            'unitValue': item.unitValue,
            'originalPrice': item.originalPrice,
            'sellingPrice': item.sellingPrice,
          },
      ],
    };
  }

  Map<String, dynamic> _outingToMap(OutingRecord outing) {
    List<Map<String, dynamic>> toLines(List<OutingLine> lines) {
      return [
        for (final line in lines)
          {
            'productId': line.productId,
            'unitType': line.unitType.name,
            'value': line.value,
            'sellingPriceOverride': line.sellingPriceOverride,
          },
      ];
    }

    return {
      'id': outing.id,
      'date': outing.date,
      'status': outing.status.name,
      'displayedProducts': toLines(outing.displayedProducts),
      'returnedProducts': toLines(outing.returnedProducts),
      'discardedProducts': toLines(outing.discardedProducts),
      'replacedDiscardedProducts': toLines(outing.replacedDiscardedProducts),
      'submittedAt': outing.submittedAt,
      'totalDisplayed': outing.totalDisplayed,
      'totalReturned': outing.totalReturned,
      'totalDiscarded': outing.totalDiscarded,
      'totalReplaced': outing.totalReplaced,
      'totalSold': outing.totalSold,
      'totalRevenue': outing.totalRevenue,
      'totalCapital': outing.totalCapital,
      'approximateProfit': outing.approximateProfit,
    };
  }

  Map<String, dynamic> _activityToMap(ActivityLog activity) {
    return {
      'id': activity.id,
      'actionType': activity.actionType.name,
      'title': activity.title,
      'description': activity.description,
      'referenceId': activity.referenceId,
      'actorUid': activity.actorUid,
      'createdAt': activity.createdAt,
      'displayed': activity.displayed,
      'returned': activity.returned,
      'discarded': activity.discarded,
      'replaced': activity.replaced,
      'sold': activity.sold,
      'profit': activity.profit,
      'lost': activity.lost,
      'productDetails': activity.productDetails,
    };
  }

  Category? _categoryFromMap(Map<String, dynamic> map) {
    final id = _asString(map['id']);
    final name = _asString(map['name']);
    if (id == null || name == null) {
      return null;
    }

    return Category(
      id: id,
      name: name,
      colorHex: _asString(map['colorHex']) ?? '#607D8B',
      requireProductImage: _asBool(map['requireProductImage']) ?? false,
      allowFlexibleSellingPrice:
          _asBool(map['allowFlexibleSellingPrice']) ?? false,
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Product? _productFromMap(Map<String, dynamic> map) {
    final id = _asString(map['id']);
    final categoryId = _asString(map['categoryId']);
    final name = _asString(map['name']);
    if (id == null || categoryId == null || name == null) {
      return null;
    }

    return Product(
      id: id,
      categoryId: categoryId,
      name: name,
      imagePath: _asString(map['imagePath']),
      costPrice: _asDouble(map['costPrice']) ?? 0,
      sellingPrice: _asDouble(map['sellingPrice']) ?? 0,
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _asDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  StockBatch? _stockBatchFromMap(Map<String, dynamic> map) {
    final id = _asString(map['id']);
    final batchName = _asString(map['batchName']);
    final itemsRaw = map['items'];
    if (id == null || batchName == null || itemsRaw is! List) {
      return null;
    }

    final items = <BatchItem>[];
    for (final item in itemsRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final productId = _asString(item['productId']);
      final unitTypeName = _asString(item['unitType']);
      final unitValue = _asDouble(item['unitValue']);
      final originalPrice = _asDouble(item['originalPrice']);
      final sellingPrice = _asDouble(item['sellingPrice']);
      if (productId == null ||
          unitTypeName == null ||
          unitValue == null ||
          originalPrice == null ||
          sellingPrice == null) {
        continue;
      }

      final unitType = BatchItem(
        productId: productId,
        unitType: _unitTypeFromName(unitTypeName),
        unitValue: unitValue,
        originalPrice: originalPrice,
        sellingPrice: sellingPrice,
      );
      items.add(unitType);
    }

    return StockBatch(
      id: id,
      batchName: batchName,
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      items: items,
    );
  }

  OutingRecord? _outingFromMap(Map<String, dynamic> map) {
    final id = _asString(map['id']);
    if (id == null) {
      return null;
    }

    return OutingRecord(
      id: id,
      date: _asDateTime(map['date']) ?? DateTime.now(),
      status: _outingStatusFromName(_asString(map['status'])),
      displayedProducts: _parseOutingLines(map['displayedProducts']),
      returnedProducts: _parseOutingLines(map['returnedProducts']),
      discardedProducts: _parseOutingLines(map['discardedProducts']),
      replacedDiscardedProducts: _parseOutingLines(
        map['replacedDiscardedProducts'],
      ),
      submittedAt: _asDateTime(map['submittedAt']),
      totalDisplayed: _asDouble(map['totalDisplayed']),
      totalReturned: _asDouble(map['totalReturned']),
      totalDiscarded: _asDouble(map['totalDiscarded']),
      totalReplaced: _asDouble(map['totalReplaced']),
      totalSold: _asDouble(map['totalSold']),
      totalRevenue: _asDouble(map['totalRevenue']),
      totalCapital: _asDouble(map['totalCapital']),
      approximateProfit: _asDouble(map['approximateProfit']),
    );
  }

  ActivityLog? _activityFromMap(Map<String, dynamic> map) {
    final id = _asString(map['id']);
    final title = _asString(map['title']);
    final description = _asString(map['description']);
    if (id == null || title == null || description == null) {
      return null;
    }

    return ActivityLog(
      id: id,
      actionType: _activityActionTypeFromName(_asString(map['actionType'])),
      title: title,
      description: description,
      referenceId: _asString(map['referenceId']),
      actorUid: _asString(map['actorUid']),
      createdAt: _asDateTime(map['createdAt']) ?? DateTime.now(),
      displayed: _asDouble(map['displayed']),
      returned: _asDouble(map['returned']),
      discarded: _asDouble(map['discarded']),
      replaced: _asDouble(map['replaced']),
      sold: _asDouble(map['sold']),
      profit: _asDouble(map['profit']),
      lost: _asDouble(map['lost']),
      productDetails: _asString(map['productDetails']),
    );
  }

  List<OutingLine> _parseOutingLines(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final lines = <OutingLine>[];
    for (final entry in value) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final productId = _asString(entry['productId']);
      final unitTypeName = _asString(entry['unitType']);
      final lineValue = _asDouble(entry['value']);
      if (productId == null || unitTypeName == null || lineValue == null) {
        continue;
      }

      lines.add(
        OutingLine(
          productId: productId,
          unitType: _unitTypeFromName(unitTypeName),
          value: lineValue,
          sellingPriceOverride: _asDouble(entry['sellingPriceOverride']),
        ),
      );
    }

    return lines;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  bool? _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  UnitType _unitTypeFromName(String? value) {
    if (value == null) {
      return UnitType.quantity;
    }
    return UnitType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => UnitType.quantity,
    );
  }

  OutingStatus _outingStatusFromName(String? value) {
    if (value == null) {
      return OutingStatus.draft;
    }
    return OutingStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OutingStatus.draft,
    );
  }

  ActivityActionType _activityActionTypeFromName(String? value) {
    if (value == null) {
      return ActivityActionType.productUpdated;
    }
    return ActivityActionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ActivityActionType.productUpdated,
    );
  }
}

class _SyncWrite {
  const _SyncWrite({required this.ref, required this.data});

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, dynamic> data;
}
