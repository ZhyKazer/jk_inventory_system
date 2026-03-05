import 'package:hive/hive.dart';

class Category {
  Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.requireProductImage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String colorHex;
  final bool requireProductImage;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    bool? requireProductImage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      requireProductImage: requireProductImage ?? this.requireProductImage,
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

    // Next int may be:
    // - createdAt millis (very old format),
    // - legacy default unit index (0/1),
    // - require image flag (0=false, 2=true).
    final maybe = reader.readInt();
    const timestampThreshold = 100000000000; // 1e11

    bool requireProductImage;
    int createdMillis;
    int updatedMillis;

    if (maybe >= timestampThreshold) {
      // Old format: maybe is createdAt
      requireProductImage = false;
      createdMillis = maybe;
      updatedMillis = reader.readInt();
    } else {
      // Legacy unit index values (0/1) are treated as false.
      requireProductImage = maybe == 2;
      createdMillis = reader.readInt();
      updatedMillis = reader.readInt();
    }

    return Category(
      id: id,
      name: name,
      colorHex: colorHex,
      requireProductImage: requireProductImage,
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
      // 0 = false, 2 = true (reserves 0/1 to avoid legacy unit index collision)
      ..writeInt(obj.requireProductImage ? 2 : 0)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
