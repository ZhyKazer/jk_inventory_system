import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/unit_type.dart';

class BatchItem {
  BatchItem({
    required this.productId,
    required this.unitType,
    required this.unitValue,
    required this.originalPrice,
    required this.sellingPrice,
  });

  final String productId;
  final UnitType unitType;
  final double unitValue;
  final double originalPrice;
  final double sellingPrice;
}

class StockBatch {
  StockBatch({
    required this.id,
    required this.batchName,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String batchName;
  final DateTime createdAt;
  final List<BatchItem> items;

  int get totalItems => items.length;
}

class StockBatchAdapter extends TypeAdapter<StockBatch> {
  @override
  final int typeId = 2;

  @override
  StockBatch read(BinaryReader reader) {
    final id = reader.readString();
    final batchName = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final itemCount = reader.readInt();

    final items = <BatchItem>[];
    for (var index = 0; index < itemCount; index++) {
      final productId = reader.readString();
      final unitType = UnitType.values[reader.readInt()];
      final unitValue = reader.readDouble();
      final originalPrice = _readDouble(reader);
      final sellingPrice = _readDouble(reader, fallback: originalPrice);

      items.add(
        BatchItem(
          productId: productId,
          unitType: unitType,
          unitValue: unitValue,
          originalPrice: originalPrice,
          sellingPrice: sellingPrice,
        ),
      );
    }

    return StockBatch(
      id: id,
      batchName: batchName,
      createdAt: createdAt,
      items: items,
    );
  }

  double _readDouble(BinaryReader reader, {double fallback = 0}) {
    try {
      return reader.readDouble();
    } catch (_) {
      return fallback;
    }
  }

  @override
  void write(BinaryWriter writer, StockBatch obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.batchName)
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.items.length);

    for (final item in obj.items) {
      writer
        ..writeString(item.productId)
        ..writeInt(item.unitType.index)
        ..writeDouble(item.unitValue)
        ..writeDouble(item.originalPrice)
        ..writeDouble(item.sellingPrice);
    }
  }
}
