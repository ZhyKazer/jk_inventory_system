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
  });

  final String id;
  final DateTime date;
  final OutingStatus status;
  final List<OutingLine> displayedProducts;
  final List<OutingLine> returnedProducts;
  final List<OutingLine> discardedProducts;
  final List<OutingLine> replacedDiscardedProducts;
  final DateTime? submittedAt;
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

    return OutingRecord(
      id: id,
      date: date,
      status: status,
      displayedProducts: displayed,
      returnedProducts: returned,
      discardedProducts: discarded,
      replacedDiscardedProducts: replaced,
      submittedAt: submittedAt,
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
  }

  List<OutingLine> _readLines(BinaryReader reader) {
    final count = reader.readInt();
    final lines = <OutingLine>[];
    for (var index = 0; index < count; index++) {
      lines.add(
        OutingLine(
          productId: reader.readString(),
          unitType: UnitType.values[reader.readInt()],
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
