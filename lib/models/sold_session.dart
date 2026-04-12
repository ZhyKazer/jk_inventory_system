import 'package:hive/hive.dart';

enum SoldSessionStatus { pendingReview, done }

class SoldProductLine {
  SoldProductLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.gcashReceiptImagePath,
    this.shopeeCheckoutImagePath,
  });

  final String productId;
  final String productName;
  final double quantity;
  final String? gcashReceiptImagePath;
  final String? shopeeCheckoutImagePath;

  SoldProductLine copyWith({
    String? productId,
    String? productName,
    double? quantity,
    Object? gcashReceiptImagePath = _noValue,
    Object? shopeeCheckoutImagePath = _noValue,
  }) {
    return SoldProductLine(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      gcashReceiptImagePath: gcashReceiptImagePath == _noValue
          ? this.gcashReceiptImagePath
          : gcashReceiptImagePath as String?,
      shopeeCheckoutImagePath: shopeeCheckoutImagePath == _noValue
          ? this.shopeeCheckoutImagePath
          : shopeeCheckoutImagePath as String?,
    );
  }

  static const _noValue = Object();
}

class SoldSession {
  SoldSession({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.lines,
    required this.status,
    this.actorUid,
  });

  final String id;
  final String username;
  final String? actorUid;
  final DateTime createdAt;
  final List<SoldProductLine> lines;
  final SoldSessionStatus status;

  double get totalQuantity {
    var total = 0.0;
    for (final line in lines) {
      total += line.quantity;
    }
    return total;
  }

  SoldSession copyWith({
    String? id,
    String? username,
    Object? actorUid = _noValue,
    DateTime? createdAt,
    List<SoldProductLine>? lines,
    SoldSessionStatus? status,
  }) {
    return SoldSession(
      id: id ?? this.id,
      username: username ?? this.username,
      actorUid: actorUid == _noValue ? this.actorUid : actorUid as String?,
      createdAt: createdAt ?? this.createdAt,
      lines: lines ?? this.lines,
      status: status ?? this.status,
    );
  }

  static const _noValue = Object();
}

class SoldSessionAdapter extends TypeAdapter<SoldSession> {
  @override
  final int typeId = 5;

  @override
  SoldSession read(BinaryReader reader) {
    final id = reader.readString();
    final username = reader.readString();
    final hasActorUid = reader.readBool();
    final actorUid = hasActorUid ? reader.readString() : null;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final status = SoldSessionStatus.values[reader.readInt()];
    final lineCount = reader.readInt();
    final lines = <SoldProductLine>[];
    for (var i = 0; i < lineCount; i++) {
      final productId = reader.readString();
      final productName = reader.readString();
      final quantity = reader.readDouble();
      final hasGcash = reader.readBool();
      final gcash = hasGcash ? reader.readString() : null;
      final hasShopee = reader.readBool();
      final shopee = hasShopee ? reader.readString() : null;
      lines.add(
        SoldProductLine(
          productId: productId,
          productName: productName,
          quantity: quantity,
          gcashReceiptImagePath: gcash,
          shopeeCheckoutImagePath: shopee,
        ),
      );
    }

    return SoldSession(
      id: id,
      username: username,
      actorUid: actorUid,
      createdAt: createdAt,
      lines: lines,
      status: status,
    );
  }

  @override
  void write(BinaryWriter writer, SoldSession obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.username)
      ..writeBool(obj.actorUid != null);
    if (obj.actorUid != null) {
      writer.writeString(obj.actorUid!);
    }
    writer
      ..writeInt(obj.createdAt.millisecondsSinceEpoch)
      ..writeInt(obj.status.index)
      ..writeInt(obj.lines.length);

    for (final line in obj.lines) {
      writer
        ..writeString(line.productId)
        ..writeString(line.productName)
        ..writeDouble(line.quantity)
        ..writeBool(line.gcashReceiptImagePath != null);
      if (line.gcashReceiptImagePath != null) {
        writer.writeString(line.gcashReceiptImagePath!);
      }
      writer.writeBool(line.shopeeCheckoutImagePath != null);
      if (line.shopeeCheckoutImagePath != null) {
        writer.writeString(line.shopeeCheckoutImagePath!);
      }
    }
  }
}
