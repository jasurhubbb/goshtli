import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

/// Partner-app theme. Inherits shared_core's brand colour and Apple-style tokens, with one tweak:
/// 56pt buttons + 18sp body so one-handed thumb use on a meat-shop floor (often wet/dusty) is easier.
class PartnerTheme {
  static ThemeData get light => AppTheme.buildLight(buttonHeight: 56);
}
