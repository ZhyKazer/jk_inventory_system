import 'package:hive/hive.dart';

class Product {
  static const Object _noImagePath = Object();

  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    this.imagePath,
    this.costPrice = 0.0,
    this.sellingPrice = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String name;
  final String? imagePath;
  final double costPrice;
  final double sellingPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product copyWith({
    String? id,
    String? categoryId,
    String? name,
    Object? imagePath = _noImagePath,
    double? costPrice,
    double? sellingPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
        imagePath: identical(imagePath, _noImagePath)
          ? this.imagePath
          : imagePath as String?,
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

    final maybeImageOrCost = reader.read();

    String? imagePath;
    double costPrice;

    if (maybeImageOrCost is String || maybeImageOrCost == null) {
      imagePath = maybeImageOrCost as String?;
      costPrice = _asDouble(reader.read(), fallback: 0.0);
    } else {
      imagePath = null;
      costPrice = _asDouble(maybeImageOrCost, fallback: 0.0);
    }

    final sellingPrice = _asDouble(reader.read(), fallback: 0.0);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(reader.read(), fallback: 0),
    );
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(
      _asInt(reader.read(), fallback: 0),
    );

    return Product(
      id: id,
      categoryId: categoryId,
      name: name,
      imagePath: imagePath,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.categoryId)
      ..writeString(obj.name)
      ..write(obj.imagePath)
      ..writeDouble(obj.costPrice)
      ..writeDouble(obj.sellingPrice)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
