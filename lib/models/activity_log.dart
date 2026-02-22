import 'package:hive/hive.dart';

enum ActivityActionType {
  categoryCreated,
  categoryUpdated,
  categoryDeleted,
  productCreated,
  productUpdated,
  productDeleted,
  batchCreated,
  outingSubmitted,
}

class ActivityLog {
  ActivityLog({
    required this.id,
    required this.actionType,
    required this.title,
    required this.description,
    required this.createdAt,
    this.referenceId,
    this.displayed,
    this.returned,
    this.discarded,
    this.replaced,
    this.sold,
    this.profit,
    this.lost,
  });

  final String id;
  final ActivityActionType actionType;
  final String title;
  final String description;
  final String? referenceId;
  final DateTime createdAt;
  final double? displayed;
  final double? returned;
  final double? discarded;
  final double? replaced;
  final double? sold;
  final double? profit;
  final double? lost;
}

class ActivityLogAdapter extends TypeAdapter<ActivityLog> {
  @override
  final int typeId = 4;

  @override
  ActivityLog read(BinaryReader reader) {
    final id = reader.readString();
    final actionType = ActivityActionType.values[reader.readInt()];
    final title = reader.readString();
    final description = reader.readString();
    final hasReferenceId = reader.readBool();
    final referenceId = hasReferenceId ? reader.readString() : null;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final hasDisplayed = reader.readBool();
    final displayed = hasDisplayed ? reader.readDouble() : null;
    final hasReturned = reader.readBool();
    final returned = hasReturned ? reader.readDouble() : null;
    final hasDiscarded = reader.readBool();
    final discarded = hasDiscarded ? reader.readDouble() : null;
    final hasReplaced = reader.readBool();
    final replaced = hasReplaced ? reader.readDouble() : null;
    final hasSold = reader.readBool();
    final sold = hasSold ? reader.readDouble() : null;
    final hasProfit = reader.readBool();
    final profit = hasProfit ? reader.readDouble() : null;
    final hasLost = reader.readBool();
    final lost = hasLost ? reader.readDouble() : null;

    return ActivityLog(
      id: id,
      actionType: actionType,
      title: title,
      description: description,
      referenceId: referenceId,
      createdAt: createdAt,
      displayed: displayed,
      returned: returned,
      discarded: discarded,
      replaced: replaced,
      sold: sold,
      profit: profit,
      lost: lost,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityLog obj) {
    writer
      ..writeString(obj.id)
      ..writeInt(obj.actionType.index)
      ..writeString(obj.title)
      ..writeString(obj.description)
      ..writeBool(obj.referenceId != null);

    if (obj.referenceId != null) {
      writer.writeString(obj.referenceId!);
    }

    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeBool(obj.displayed != null);
    if (obj.displayed != null) writer.writeDouble(obj.displayed!);
    writer.writeBool(obj.returned != null);
    if (obj.returned != null) writer.writeDouble(obj.returned!);
    writer.writeBool(obj.discarded != null);
    if (obj.discarded != null) writer.writeDouble(obj.discarded!);
    writer.writeBool(obj.replaced != null);
    if (obj.replaced != null) writer.writeDouble(obj.replaced!);
    writer.writeBool(obj.sold != null);
    if (obj.sold != null) writer.writeDouble(obj.sold!);
    writer.writeBool(obj.profit != null);
    if (obj.profit != null) writer.writeDouble(obj.profit!);
    writer.writeBool(obj.lost != null);
    if (obj.lost != null) writer.writeDouble(obj.lost!);
  }
}
