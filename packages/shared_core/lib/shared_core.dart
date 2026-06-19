/// shared_core — cross-app utilities for Go'sht Bozori buyer + partner apps.
///
/// Export everything callers need from a single import:
///   import 'package:shared_core/shared_core.dart';
library shared_core;

export 'api/api_client.dart';
export 'api/api_exception.dart';
export 'auth/token_storage.dart';
export 'auth/firebase_phone_bridge.dart';
export 'auth/auth_state.dart';
export 'locale/locale_notifier.dart';
export 'models/user.dart';
export 'theme/app_theme.dart';
