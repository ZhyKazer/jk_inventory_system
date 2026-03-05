import 'package:hive/hive.dart';
import 'package:jk_inventory_system/models/unit_type.dart';

enum OutingStatus {
  draft,
  submitted,
}

class OutingLine {
  OutingLine({
    required this.productId,
    required this.unitType,
    required this.value,
  });

  final String productId;
  final UnitType unitType;
  final double value;
}

class OutingRecord {
  OutingRecord({
    required this.id,
    required this.date,
    required this.status,
    required this.displayedProducts,
    required this.returnedProducts,
    required this.discardedProducts,
    required this.replacedDiscardedProducts,
    this.submittedAt,
    this.totalDisplayed,
    this.totalReturned,
    this.totalDiscarded,
    this.totalReplaced,
    this.totalSold,
    this.totalRevenue,
    this.totalCapital,
    this.approximateProfit,
  });

  final String id;
  final DateTime date;
  final OutingStatus status;
  final List<OutingLine> displayedProducts;
  final List<OutingLine> returnedProducts;
  final List<OutingLine> discardedProducts;
  final List<OutingLine> replacedDiscardedProducts;
  final DateTime? submittedAt;
  final double? totalDisplayed;
  final double? totalReturned;
  final double? totalDiscarded;
  final double? totalReplaced;
  final double? totalSold;
  final double? totalRevenue;
  final double? totalCapital;
  final double? approximateProfit;
}

class OutingRecordAdapter extends TypeAdapter<OutingRecord> {
  @override
  final int typeId = 3;

  @override
  OutingRecord read(BinaryReader reader) {
    final id = reader.readString();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final status = OutingStatus.values[reader.readInt()];
    final displayed = _readLines(reader);
    final returned = _readLines(reader);
    final discarded = _readLines(reader);
    final replaced = _readLines(reader);
    final hasSubmittedAt = reader.readBool();
    final submittedAt = hasSubmittedAt
        ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
        : null;

    double? totalDisplayed;
    double? totalReturned;
    double? totalDiscarded;
    double? totalReplaced;
    double? totalSold;
    double? totalRevenue;
    double? totalCapital;
    double? approximateProfit;

    try {
      totalDisplayed = reader.readBool() ? reader.readDouble() : null;
      totalReturned = reader.readBool() ? reader.readDouble() : null;
      totalDiscarded = reader.readBool() ? reader.readDouble() : null;
      totalReplaced = reader.readBool() ? reader.readDouble() : null;
      totalSold = reader.readBool() ? reader.readDouble() : null;
      totalRevenue = reader.readBool() ? reader.readDouble() : null;
      totalCapital = reader.readBool() ? reader.readDouble() : null;
      approximateProfit = reader.readBool() ? reader.readDouble() : null;
    } catch (_) {
      totalDisplayed = null;
      totalReturned = null;
      totalDiscarded = null;
      totalReplaced = null;
      totalSold = null;
      totalRevenue = null;
      totalCapital = null;
      approximateProfit = null;
    }

    return OutingRecord(
      id: id,
      date: date,
      status: status,
      displayedProducts: displayed,
      returnedProducts: returned,
      discardedProducts: discarded,
      replacedDiscardedProducts: replaced,
      submittedAt: submittedAt,
      totalDisplayed: totalDisplayed,
      totalReturned: totalReturned,
      totalDiscarded: totalDiscarded,
      totalReplaced: totalReplaced,
      totalSold: totalSold,
      totalRevenue: totalRevenue,
      totalCapital: totalCapital,
      approximateProfit: approximateProfit,
    );
  }

  @override
  void write(BinaryWriter writer, OutingRecord obj) {
    writer
      ..writeString(obj.id)
      ..writeInt(obj.date.millisecondsSinceEpoch)
      ..writeInt(obj.status.index);

    _writeLines(writer, obj.displayedProducts);
    _writeLines(writer, obj.returnedProducts);
    _writeLines(writer, obj.discardedProducts);
    _writeLines(writer, obj.replacedDiscardedProducts);

    writer.writeBool(obj.submittedAt != null);
    if (obj.submittedAt != null) {
      writer.writeInt(obj.submittedAt!.millisecondsSinceEpoch);
    }

    writer.writeBool(obj.totalDisplayed != null);
    if (obj.totalDisplayed != null) writer.writeDouble(obj.totalDisplayed!);

    writer.writeBool(obj.totalReturned != null);
    if (obj.totalReturned != null) writer.writeDouble(obj.totalReturned!);

    writer.writeBool(obj.totalDiscarded != null);
    if (obj.totalDiscarded != null) writer.writeDouble(obj.totalDiscarded!);

    writer.writeBool(obj.totalReplaced != null);
    if (obj.totalReplaced != null) writer.writeDouble(obj.totalReplaced!);

    writer.writeBool(obj.totalSold != null);
    if (obj.totalSold != null) writer.writeDouble(obj.totalSold!);

    writer.writeBool(obj.totalRevenue != null);
    if (obj.totalRevenue != null) writer.writeDouble(obj.totalRevenue!);

    writer.writeBool(obj.totalCapital != null);
    if (obj.totalCapital != null) writer.writeDouble(obj.totalCapital!);

    writer.writeBool(obj.approximateProfit != null);
    if (obj.approximateProfit != null) writer.writeDouble(obj.approximateProfit!);
  }

  List<OutingLine> _readLines(BinaryReader reader) {
    final count = reader.readInt();
    final lines = <OutingLine>[];
    for (var index = 0; index < count; index++) {
      final productId = reader.readString();
      final unitIndex = reader.readInt();
      lines.add(
        OutingLine(
          productId: productId,
          unitType: unitIndex >= 0 && unitIndex < UnitType.values.length
              ? UnitType.values[unitIndex]
              : UnitType.quantity,
          value: reader.readDouble(),
        ),
      );
    }
    return lines;
  }

  void _writeLines(BinaryWriter writer, List<OutingLine> lines) {
    writer.writeInt(lines.length);
    for (final line in lines) {
      writer
        ..writeString(line.productId)
        ..writeInt(line.unitType.index)
        ..writeDouble(line.value);
    }
  }
}
