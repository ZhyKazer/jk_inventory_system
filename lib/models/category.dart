import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/unit_type.dart';

class Category {
  Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.defaultUnit,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String colorHex;
  final UnitType defaultUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    UnitType? defaultUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 0;

  @override
  Category read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final colorHex = reader.readString();

    // Next int may be either the `defaultUnit` index (new format) or the createdAt millis (old format).
    final maybe = reader.readInt();
    const timestampThreshold = 100000000000; // 1e11

    UnitType defaultUnit;
    int createdMillis;
    int updatedMillis;

    if (maybe >= timestampThreshold) {
      // Old format: maybe is createdAt
      defaultUnit = UnitType.quantity;
      createdMillis = maybe;
      updatedMillis = reader.readInt();
    } else {
      // New format: maybe is unit index
      if (maybe >= 0 && maybe < UnitType.values.length) {
        defaultUnit = UnitType.values[maybe];
      } else {
        defaultUnit = UnitType.quantity;
      }
      createdMillis = reader.readInt();
      updatedMillis = reader.readInt();
    }

    return Category(
      id: id,
      name: name,
      colorHex: colorHex,
      defaultUnit: defaultUnit,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMillis),
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.colorHex)
      // write enum index for default unit
      ..writeInt(obj.defaultUnit.index)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
