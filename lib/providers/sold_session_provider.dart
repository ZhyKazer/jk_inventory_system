import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/sold_session.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';
import 'package:jk_inventory_system/services/firebase_sync_service.dart';
import 'package:jk_inventory_system/services/inventory_stock_calculator.dart';
import 'package:uuid/uuid.dart';

class SoldSessionProvider extends ChangeNotifier {
  SoldSessionProvider(
    this._repository, {
    required List<StockBatch> Function() getBatches,
    required List<OutingRecord> Function() getOutings,
    FirebaseSyncService? syncService,
  }) : _getBatches = getBatches,
       _getOutings = getOutings,
       _syncService = syncService ?? FirebaseSyncService();

  final SoldSessionRepositoryInterface _repository;
  final List<StockBatch> Function() _getBatches;
  final List<OutingRecord> Function() _getOutings;
  final FirebaseSyncService _syncService;
  final InventoryStockCalculator _stockCalculator =
      const InventoryStockCalculator();
  final Uuid _uuid = const Uuid();

  List<SoldSession> _items = [];
  List<SoldProductLine> _draftLines = [];
  String _draftCustomerName = '';

  List<SoldSession> get items => List.unmodifiable(_items);
  List<SoldProductLine> get draftLines => List.unmodifiable(_draftLines);
  String get draftCustomerName => _draftCustomerName;

  double _draftQuantityFor(String productId) {
    var total = 0.0;
    for (final line in _draftLines) {
      if (line.productId == productId) {
        total += line.quantity;
      }
    }
    return total;
  }

  double _currentAvailableQuantity(String productId) {
    return _stockCalculator.currentStock(
      productId: productId,
      unitType: UnitType.quantity,
      batches: _getBatches(),
      outings: _getOutings(),
      soldSessions: _items,
    );
  }

  Future<void> load() async {
    _items = _repository.getAll();
    notifyListeners();
  }

  void startDraft({bool notify = true}) {
    final hadDraft = _draftLines.isNotEmpty;
    _draftLines = [];
    _draftCustomerName = '';
    if (notify && hadDraft) {
      notifyListeners();
    }
  }

  void setDraftCustomerName(String name) {
    _draftCustomerName = name;
    notifyListeners();
  }

  String? addDraftLine({
    required String productId,
    required String productName,
    required double quantity,
    String? gcashReceiptImagePath,
    String? shopeeCheckoutImagePath,
  }) {
    if (productId.trim().isEmpty) {
      return 'Product is required.';
    }
    if (quantity <= 0) {
      return 'Quantity must be greater than 0.';
    }

    final normalizedProductId = productId.trim();
    final available = _currentAvailableQuantity(normalizedProductId);
    final remaining = available - _draftQuantityFor(normalizedProductId);
    if (remaining <= 0) {
      return 'No available quantity left for this product.';
    }
    if (quantity > remaining) {
      return 'Quantity cannot exceed available stock (${remaining.toStringAsFixed(2)}).';
    }

    _draftLines = [
      ..._draftLines,
      SoldProductLine(
        productId: normalizedProductId,
        productName: productName.trim(),
        quantity: quantity,
        gcashReceiptImagePath: (gcashReceiptImagePath ?? '').trim().isEmpty
            ? null
            : gcashReceiptImagePath!.trim(),
        shopeeCheckoutImagePath: (shopeeCheckoutImagePath ?? '').trim().isEmpty
            ? null
            : shopeeCheckoutImagePath!.trim(),
      ),
    ];
    notifyListeners();
    return null;
  }

  void removeDraftLine(int index) {
    _draftLines = [..._draftLines]..removeAt(index);
    notifyListeners();
  }

  void setGcashImagePath(int index, String imagePath) {
    final current = _draftLines[index];
    _draftLines = [..._draftLines]
      ..[index] = current.copyWith(gcashReceiptImagePath: imagePath);
    notifyListeners();
  }

  void setShopeeImagePath(int index, String imagePath) {
    final current = _draftLines[index];
    _draftLines = [..._draftLines]
      ..[index] = current.copyWith(shopeeCheckoutImagePath: imagePath);
    notifyListeners();
  }

  void setAllGcashImagePath(String imagePath) {
    _draftLines = [
      for (final line in _draftLines)
        line.copyWith(gcashReceiptImagePath: imagePath),
    ];
    notifyListeners();
  }

  void setAllShopeeImagePath(String imagePath) {
    _draftLines = [
      for (final line in _draftLines)
        line.copyWith(shopeeCheckoutImagePath: imagePath),
    ];
    notifyListeners();
  }

  bool get canContinueToReview {
    if (_draftLines.isEmpty) {
      return false;
    }
    for (final line in _draftLines) {
      if ((line.gcashReceiptImagePath ?? '').trim().isEmpty) {
        return false;
      }
      if ((line.shopeeCheckoutImagePath ?? '').trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<String?> submitDraft({required String username}) async {
    final normalizedUsername = username.trim();
    final normalizedCustomerName = _draftCustomerName.trim();
    if (normalizedUsername.isEmpty) {
      return 'Unable to submit: username is missing.';
    }
    if (normalizedCustomerName.isEmpty) {
      return 'Customer name is required.';
    }

    if (_draftLines.isEmpty) {
      return 'Add at least one sold product before submitting.';
    }

    if (!canContinueToReview) {
      return 'Each sold product must have both GCash receipt and Shopee checkout images.';
    }

    final requestedByProduct = <String, double>{};
    for (final line in _draftLines) {
      requestedByProduct.update(
        line.productId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    for (final entry in requestedByProduct.entries) {
      final available = _currentAvailableQuantity(entry.key);
      if (entry.value > available) {
        return 'Insufficient stock for one or more products. Please review quantities before submitting.';
      }
    }

    final session = SoldSession(
      id: _uuid.v4(),
      username: normalizedUsername,
      customerName: normalizedCustomerName,
      actorUid: FirebaseAuth.instance.currentUser?.uid,
      createdAt: DateTime.now(),
      lines: List<SoldProductLine>.from(_draftLines),
      status: SoldSessionStatus.pendingReview,
    );

    await _repository.create(session);
    try {
      await _syncService.upsertSoldSession(session);
    } catch (error) {
      debugPrint('Firebase sold session auto-sync failed: $error');
    }

    await load();
    startDraft();
    return null;
  }

  Future<void> markDone(String sessionId) async {
    SoldSession? target;
    for (final item in _items) {
      if (item.id == sessionId) {
        target = item;
        break;
      }
    }
    if (target == null || target.status == SoldSessionStatus.done) {
      return;
    }

    final updated = target.copyWith(status: SoldSessionStatus.done);
    await _repository.update(updated);
    try {
      await _syncService.upsertSoldSession(updated);
    } catch (error) {
      debugPrint('Firebase sold session done auto-sync failed: $error');
    }
    await load();
  }

  Future<void> updateDeliveryStatus(
    String sessionId, {
    bool? isPackaging,
    bool? isDroppedOff,
    bool? isDelivered,
  }) async {
    SoldSession? target;
    for (final item in _items) {
      if (item.id == sessionId) {
        target = item;
        break;
      }
    }
    if (target == null) {
      return;
    }

    var nextPackaging = isPackaging ?? target.isPackaging;
    var nextDroppedOff = isDroppedOff ?? target.isDroppedOff;
    var nextDelivered = isDelivered ?? target.isDelivered;

    if (!nextPackaging) {
      nextDroppedOff = false;
      nextDelivered = false;
    }
    if (!nextDroppedOff) {
      nextDelivered = false;
    }

    final updated = target.copyWith(
      isPackaging: nextPackaging,
      isDroppedOff: nextDroppedOff,
      isDelivered: nextDelivered,
    );
    await _repository.update(updated);
    try {
      await _syncService.upsertSoldSession(updated);
    } catch (error) {
      debugPrint('Firebase sold session status auto-sync failed: $error');
    }
    await load();
  }

  Future<void> setArchived(String sessionId, {required bool archived}) async {
    SoldSession? target;
    for (final item in _items) {
      if (item.id == sessionId) {
        target = item;
        break;
      }
    }
    if (target == null) {
      return;
    }

    final updated = target.copyWith(isArchived: archived);
    await _repository.update(updated);
    try {
      await _syncService.upsertSoldSession(updated);
    } catch (error) {
      debugPrint('Firebase sold session archive auto-sync failed: $error');
    }
    await load();
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.delete(sessionId);
    try {
      await _syncService.deleteSoldSession(sessionId);
    } catch (error) {
      debugPrint('Firebase sold session delete failed: $error');
    }
    await load();
  }
}
