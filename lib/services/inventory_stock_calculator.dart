import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';

enum InventoryMovementType {
  batchIn,
  displayedOut,
  returnedIn,
  discardedOut,
  discardedReplacedIn,
}

class InventoryLedgerEntry {
  InventoryLedgerEntry({
    required this.productId,
    required this.movementType,
    required this.unitType,
    required this.value,
    required this.referenceId,
    required this.createdAt,
    this.price,
  });

  final String productId;
  final InventoryMovementType movementType;
  final UnitType unitType;
  final double value;
  final double? price;
  final String referenceId;
  final DateTime createdAt;
}

class InventoryStockCalculator {
  const InventoryStockCalculator();

  List<InventoryLedgerEntry> buildLedger({
    required List<StockBatch> batches,
    required List<OutingRecord> outings,
  }) {
    final entries = <InventoryLedgerEntry>[];

    for (final batch in batches) {
      for (final item in batch.items) {
        entries.add(
          InventoryLedgerEntry(
            productId: item.productId,
            movementType: InventoryMovementType.batchIn,
            unitType: item.unitType,
            value: item.unitValue,
            price: item.originalPrice,
            referenceId: batch.id,
            createdAt: batch.createdAt,
          ),
        );
      }
    }

    for (final outing in outings.where(
      (item) => item.status == OutingStatus.submitted,
    )) {
      for (final line in outing.displayedProducts) {
        entries.add(
          InventoryLedgerEntry(
            productId: line.productId,
            movementType: InventoryMovementType.displayedOut,
            unitType: line.unitType,
            value: line.value,
            referenceId: outing.id,
            createdAt: outing.submittedAt ?? outing.date,
          ),
        );
      }
      for (final line in outing.returnedProducts) {
        entries.add(
          InventoryLedgerEntry(
            productId: line.productId,
            movementType: InventoryMovementType.returnedIn,
            unitType: line.unitType,
            value: line.value,
            referenceId: outing.id,
            createdAt: outing.submittedAt ?? outing.date,
          ),
        );
      }
      for (final line in outing.discardedProducts) {
        entries.add(
          InventoryLedgerEntry(
            productId: line.productId,
            movementType: InventoryMovementType.discardedOut,
            unitType: line.unitType,
            value: line.value,
            referenceId: outing.id,
            createdAt: outing.submittedAt ?? outing.date,
          ),
        );
      }
      for (final line in outing.replacedDiscardedProducts) {
        entries.add(
          InventoryLedgerEntry(
            productId: line.productId,
            movementType: InventoryMovementType.discardedReplacedIn,
            unitType: line.unitType,
            value: line.value,
            referenceId: outing.id,
            createdAt: outing.submittedAt ?? outing.date,
          ),
        );
      }
    }

    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  double currentStock({
    required String productId,
    required UnitType unitType,
    required List<StockBatch> batches,
    required List<OutingRecord> outings,
  }) {
    return _stockFromLedger(
      entries: buildLedger(batches: batches, outings: outings),
      productId: productId,
      unitType: unitType,
    );
  }

  double displayedLimit({
    required String productId,
    required UnitType unitType,
    required DateTime date,
    required List<StockBatch> batches,
    required List<OutingRecord> outings,
  }) {
    final startOfDate = DateTime(date.year, date.month, date.day);
    return _stockFromLedger(
      entries: buildLedger(
        batches: batches,
        outings: outings,
      ).where((entry) => entry.createdAt.isBefore(startOfDate)).toList(),
      productId: productId,
      unitType: unitType,
    );
  }

  double discardedLimit({
    required String productId,
    required UnitType unitType,
    required DateTime date,
    required List<StockBatch> batches,
    required List<OutingRecord> outings,
  }) {
    return displayedLimit(
      productId: productId,
      unitType: unitType,
      date: date,
      batches: batches,
      outings: outings,
    );
  }

  double _stockFromLedger({
    required List<InventoryLedgerEntry> entries,
    required String productId,
    required UnitType unitType,
  }) {
    var total = 0.0;
    for (final entry in entries) {
      if (entry.productId != productId || entry.unitType != unitType) {
        continue;
      }
      total += _signedMovement(entry);
    }
    return total;
  }

  double _signedMovement(InventoryLedgerEntry entry) {
    switch (entry.movementType) {
      case InventoryMovementType.batchIn:
      case InventoryMovementType.returnedIn:
      case InventoryMovementType.discardedReplacedIn:
        return entry.value;
      case InventoryMovementType.displayedOut:
      case InventoryMovementType.discardedOut:
        return -entry.value;
    }
  }
}
