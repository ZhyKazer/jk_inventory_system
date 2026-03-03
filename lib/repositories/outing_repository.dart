import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';

class OutingRepository implements OutingRepositoryInterface {
  OutingRepository(this._box);

  final Box<OutingRecord> _box;

  List<OutingRecord> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  Future<void> create(OutingRecord record) => _box.put(record.id, record);
}
