import 'package:flutter/material.dart';

class AppRadii {
  static const BorderRadius r12 = BorderRadius.all(Radius.circular(12));
  static const BorderRadius r16 = BorderRadius.all(Radius.circular(16));
  static const BorderRadius r20 = BorderRadius.all(Radius.circular(20));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static const double sheetTopValue = 20;
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(sheetTopValue),
  );
}
