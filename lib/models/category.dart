import 'package:hive/hive.dart';

class Category {
  Category({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.requireProductImage,
    required this.allowFlexibleSellingPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String colorHex;
  final bool requireProductImage;
  final bool allowFlexibleSellingPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    bool? requireProductImage,
    bool? allowFlexibleSellingPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      requireProductImage: requireProductImage ?? this.requireProductImage,
      allowFlexibleSellingPrice:
          allowFlexibleSellingPrice ?? this.allowFlexibleSellingPrice,
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
    // - flag bitset (2=require image, 4=allow flexible selling price).
    final maybe = reader.readInt();
    const timestampThreshold = 100000000000; // 1e11

    bool requireProductImage;
    bool allowFlexibleSellingPrice;
    int createdMillis;
    int updatedMillis;

    if (maybe >= timestampThreshold) {
      // Old format: maybe is createdAt
      requireProductImage = false;
      allowFlexibleSellingPrice = false;
      createdMillis = maybe;
      updatedMillis = reader.readInt();
    } else {
      // Legacy unit index values (0/1) remain false for both flags.
      requireProductImage = (maybe & 2) == 2;
      allowFlexibleSellingPrice = (maybe & 4) == 4;
      createdMillis = reader.readInt();
      updatedMillis = reader.readInt();
    }

    return Category(
      id: id,
      name: name,
      colorHex: colorHex,
      requireProductImage: requireProductImage,
      allowFlexibleSellingPrice: allowFlexibleSellingPrice,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMillis),
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    final flags =
        (obj.requireProductImage ? 2 : 0) |
        (obj.allowFlexibleSellingPrice ? 4 : 0);

    writer
      ..writeString(obj.id)
      ..writeString(obj.name)
      ..writeString(obj.colorHex)
      // Bitset: 2=require product image, 4=allow flexible selling price.
      // 0/1 are reserved to avoid legacy unit index collisions.
      ..writeInt(flags)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
