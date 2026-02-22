import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/repositories/activity_log_repository.dart';

class ActivityLogProvider extends ChangeNotifier {
  ActivityLogProvider(this._repository);

  final ActivityLogRepository _repository;
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
  }) async {
    final item = ActivityLog(
      id: _uuid.v4(),
      actionType: actionType,
      title: title,
      description: description,
      referenceId: referenceId,
      createdAt: DateTime.now(),
      displayed: displayed,
      returned: returned,
      discarded: discarded,
      replaced: replaced,
      sold: sold,
      profit: profit,
      lost: lost,
    );

    await _repository.create(item);
    await load();
  }
}
