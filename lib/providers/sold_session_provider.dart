import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:jk_inventory_system/models/sold_session.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';
import 'package:jk_inventory_system/services/firebase_sync_service.dart';
import 'package:uuid/uuid.dart';

class SoldSessionProvider extends ChangeNotifier {
  SoldSessionProvider(this._repository, {FirebaseSyncService? syncService})
    : _syncService = syncService ?? FirebaseSyncService();

  final SoldSessionRepositoryInterface _repository;
  final FirebaseSyncService _syncService;
  final Uuid _uuid = const Uuid();

  List<SoldSession> _items = [];
  List<SoldProductLine> _draftLines = [];

  List<SoldSession> get items => List.unmodifiable(_items);
  List<SoldProductLine> get draftLines => List.unmodifiable(_draftLines);

  Future<void> load() async {
    _items = _repository.getAll();
    notifyListeners();
  }

  void startDraft({bool notify = true}) {
    final hadDraft = _draftLines.isNotEmpty;
    _draftLines = [];
    if (notify && hadDraft) {
      notifyListeners();
    }
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

    _draftLines = [
      ..._draftLines,
      SoldProductLine(
        productId: productId.trim(),
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
    if (normalizedUsername.isEmpty) {
      return 'Unable to submit: username is missing.';
    }

    if (_draftLines.isEmpty) {
      return 'Add at least one sold product before submitting.';
    }

    if (!canContinueToReview) {
      return 'Each sold product must have both GCash receipt and Shopee checkout images.';
    }

    final session = SoldSession(
      id: _uuid.v4(),
      username: normalizedUsername,
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
}
