import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/activity_log.dart';

class ActivityLogRepository {
  ActivityLogRepository(this._box);

  final Box<ActivityLog> _box;

  List<ActivityLog> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> create(ActivityLog activityLog) =>
      _box.put(activityLog.id, activityLog);
}
