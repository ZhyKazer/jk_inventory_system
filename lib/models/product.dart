import 'package:hive/hive.dart';

class Product {
  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    this.costPrice = 0.0,
    this.sellingPrice = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String name;
  final double costPrice;
  final double sellingPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product copyWith({
    String? id,
    String? categoryId,
    String? name,
    double? costPrice,
    double? sellingPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 1;

  @override
  Product read(BinaryReader reader) {
    final id = reader.readString();
    final categoryId = reader.readString();
    final name = reader.readString();
    final costPrice = _readDouble(reader, fallback: 0.0);
    final sellingPrice = _readDouble(reader, fallback: 0.0);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return Product(
      id: id,
      categoryId: categoryId,
      name: name,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  double _readDouble(BinaryReader reader, {double fallback = 0.0}) {
    try {
      return reader.readDouble();
    } catch (_) {
      return fallback;
    }
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.categoryId)
      ..writeString(obj.name)
      ..writeDouble(obj.costPrice)
      ..writeDouble(obj.sellingPrice)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
