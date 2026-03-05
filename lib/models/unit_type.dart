enum UnitType {
  quantity,
}

extension UnitTypeX on UnitType {
  String get label {
    switch (this) {
      case UnitType.quantity:
        return 'Quantity';
    }
  }
}
