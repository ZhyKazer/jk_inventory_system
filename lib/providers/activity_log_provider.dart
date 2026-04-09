import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';
import 'package:jk_inventory_system/services/firebase_sync_service.dart';

class ActivityLogProvider extends ChangeNotifier {
  ActivityLogProvider(this._repository, {FirebaseSyncService? syncService})
    : _syncService = syncService ?? FirebaseSyncService();

  final ActivityLogRepositoryInterface _repository;
  final FirebaseSyncService _syncService;
  final _uuid = const Uuid();

  List<ActivityLog> _items = [];

  List<ActivityLog> get items => List.unmodifiable(_items);

  Future<void> load() async {
    _items = _repository.getAll();
    notifyListeners();
  }

  Future<void> log({
    required ActivityActionType actionType,
    required String title,
    required String description,
    String? referenceId,
    double? displayed,
    double? returned,
    double? discarded,
    double? replaced,
    double? sold,
    double? profit,
    double? lost,
    String? productDetails,
  }) async {
    final item = ActivityLog(
      id: _uuid.v4(),
      actionType: actionType,
      title: title,
      description: description,
      referenceId: referenceId,
      createdAt: DateTime.now(),
      actorUid: FirebaseAuth.instance.currentUser?.uid,
      displayed: displayed,
      returned: returned,
      discarded: discarded,
      replaced: replaced,
      sold: sold,
      profit: profit,
      lost: lost,
      productDetails: productDetails,
    );

    await _repository.create(item);
    try {
      await _syncService.upsertActivity(item);
    } catch (error) {
      debugPrint('Firebase activity auto-sync failed: $error');
    }
    await load();
  }
}
