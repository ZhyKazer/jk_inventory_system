import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/sold_session.dart';
import 'package:jk_inventory_system/repositories/inventory_repo_interfaces.dart';

class SoldSessionRepository implements SoldSessionRepositoryInterface {
  SoldSessionRepository(this._box);

  final Box<SoldSession> _box;

  @override
  List<SoldSession> getAll() {
    final items = _box.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> create(SoldSession session) => _box.put(session.id, session);

  @override
  Future<void> update(SoldSession session) => _box.put(session.id, session);

  @override
  Future<void> delete(String id) => _box.delete(id);
}
