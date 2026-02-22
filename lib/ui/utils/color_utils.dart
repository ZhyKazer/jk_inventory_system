import 'package:flutter/material.dart';

String colorToHex(Color color) {
  final value = color.toARGB32();
  return value.toRadixString(16).padLeft(8, '0').toUpperCase();
}

Color colorFromHex(String hex) {
  final normalized = hex.replaceAll('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return Colors.grey;
  return Color(value);
}
