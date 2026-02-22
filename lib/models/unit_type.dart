enum UnitType {
  quantity,
  kilo,
}

extension UnitTypeX on UnitType {
  String get label {
    switch (this) {
      case UnitType.quantity:
        return 'Quantity';
      case UnitType.kilo:
        return 'Kilo';
    }
  }
}
